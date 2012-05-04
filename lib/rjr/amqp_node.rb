# RJR AMQP Endpoint
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the AGPLv3+ http://www.gnu.org/licenses/agpl.txt

# establish client connection w/ specified args and invoke block w/ 
# newly created client, returning it after block terminates

require 'amqp'
require 'thread'
require 'rjr/node'
require 'rjr/message'

module RJR

# AMQP client node callback interface,
# send data back to client via AMQP.
class AMQPNodeCallback
  def initialize(args = {})
    @exchange    = args[:exchange]
    @exchange_lock = args[:exchange_lock]
    @destination = args[:destination]
    @message_headers = args[:headers]
    @disconnected = false

    @exchange_lock.synchronize{
      # FIXME should disconnect all callbacks on_return
      @exchange.on_return do |basic_return, metadata, payload|
          puts "#{payload} was returned! reply_code = #{basic_return.reply_code}, reply_text = #{basic_return.reply_text}"
          @disconnected = true
      end
    }
  end

  def invoke(callback_method, *data)
    msg = RequestMessage.new :method => callback_method, :args => data, :headers => @message_headers
    raise RJR::Errors::ConnectionError.new("client unreachable") if @disconnected
    @exchange_lock.synchronize{
      @exchange.publish(msg.to_s, :routing_key => @destination, :mandatory => true)
    }
  end
end

# AMQP node definition, listen for and invoke json-rpc requests  over AMQP
class AMQPNode < RJR::Node
  RJR_NODE_TYPE = :amqp


  private
  def handle_message(metadata, msg)
    if RequestMessage.is_request_message?(msg)
      reply_to = metadata.reply_to

      # TODO should delete handler threads as they complete & should handle timeout
      @thread_pool << ThreadPoolJob.new { handle_request(reply_to, msg) }

    elsif ResponseMessage.is_response_message?(msg)
      # TODO test message, make sure it is a response message
      msg    = ResponseMessage.new(:message => msg, :headers => @message_headers)
      lock   = @message_locks[msg.msg_id]
      if lock
        headers = @message_headers.merge(msg.headers)
        begin
          res = Dispatcher.handle_response(msg.result)
          lock << res
        rescue Exception => e
          lock << nil
          lock << e
        ensure
          lock[0].synchronize { lock[1].signal }
        end
      end

    end
  end

  def handle_request(reply_to, message)
    msg    = RequestMessage.new(:message => message, :headers => @message_headers)
    headers = @message_headers.merge(msg.headers) # append request message headers
    result = Dispatcher.dispatch_request(msg.jr_method,
                                         :method_args => msg.jr_args,
                                         :headers => headers,
                                         :rjr_node_id   => @node_id,
                                         :rjr_node_type => RJR_NODE_TYPE,
                                         :rjr_callback =>
                                           AMQPNodeCallback.new(:exchange => @exchange,
                                                                :exchange_lock => @exchange_lock,
                                                                :destination => reply_to,
                                                                :headers => headers))
    response = ResponseMessage.new(:id => msg.msg_id, :result => result, :headers => headers)
    @exchange_lock.synchronize{
      @exchange.publish(response.to_s, :routing_key => reply_to)
    }
  end

  public

  # initialize the node w/ the specified params
  def initialize(args = {})
     super(args)
     @broker    = args[:broker]

     # tuple of message ids to locks/condition variables for the responses
     # of those messages with optional result response
     @message_locks = {}
  end

  # Initialize the amqp subsystem
  def init_node
     @conn = AMQP.connect(:host => @broker)
     @conn.on_tcp_connection_failure { puts "OTCF #{@node_id}" }

     ### connect to qpid broker
     @channel = AMQP::Channel.new(@conn)

     # qpid constructs that will be created for node
     @queue_name  = "#{@node_id.to_s}-queue"
     @queue       = @channel.queue(@queue_name, :auto_delete => true)
     @exchange    = @channel.default_exchange
     @exchange_lock = Mutex.new
  end

  # Instruct Node to start listening for and dispatching rpc requests
  def listen
    em_run do
      init_node

      # start receiving messages
      @queue.subscribe do |metadata, msg|
         handle_message(metadata, msg)
      end
    end
  end

  # Instructs node to send rpc request, and wait for / return response
  def invoke_request(routing_key, rpc_method, *args)
    req_mutex = Mutex.new
    req_cv = ConditionVariable.new

    message = RequestMessage.new :method => rpc_method,
                                 :args   => args,
                                 :headers => @message_headers
    em_run do
      init_node

      @message_locks[message.msg_id] = [req_mutex, req_cv]

      # begin listening for result
      @queue.subscribe do |metadata, msg|
        handle_message(metadata, msg)
      end

      @exchange_lock.synchronize{
        @exchange.publish(message.to_s, :routing_key => routing_key, :reply_to => @queue_name)
      }
    end

    ## wait for result
    # TODO - make this optional, eg a non-blocking operation mode
    #        (allowing event handler registration to be run on success / fail / etc)
    req_mutex.synchronize { req_cv.wait(req_mutex) }
    result = @message_locks[message.msg_id][2] 
    error  = @message_locks[message.msg_id].size > 3 ?
                 @message_locks[message.msg_id][3]   :
                 nil
    @message_locks.delete(message.msg_id)
    self.stop
    self.join unless self.em_running?
    raise error unless error.nil?
    return result
  end

end
end
