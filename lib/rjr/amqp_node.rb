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
    @node        = args[:node]
    @destination = args[:destination]
  end

  def invoke(callback_method, *data)
    msg = RequestMessage.new :method => callback_method, :args => data, :headers => @message_headers
    @node.publish msg.to_s, :routing_key => @destination, :mandatory => true
  end
end

# AMQP node definition, listen for and invoke json-rpc requests  over AMQP
class AMQPNode < RJR::Node
  RJR_NODE_TYPE = :amqp

  private
  def handle_message(metadata, msg)
    if RequestMessage.is_request_message?(msg)
      reply_to = metadata.reply_to
      @thread_pool << ThreadPoolJob.new { handle_request(reply_to, msg) }

    elsif ResponseMessage.is_response_message?(msg)
      handle_response(msg)

    end
  end

  def handle_request(reply_to, message)
    msg    = RequestMessage.new(:message => message, :headers => @message_headers)
    headers = @message_headers.merge(msg.headers) # append request message headers
    result = Dispatcher.dispatch_request(msg.jr_method,
                                         :method_args => msg.jr_args,
                                         :headers => headers,
                                         :client_ip => nil,    # since client doesn't directly connect to server, we can't leverage
                                         :client_port => nil,  # client ip / port for requests received via the amqp node type
                                         :rjr_node      => self,
                                         :rjr_node_id   => @node_id,
                                         :rjr_node_type => RJR_NODE_TYPE,
                                         :rjr_callback =>
                                           AMQPNodeCallback.new(:node => self,
                                                                :exchange => @exchange,
                                                                :amqp_lock => @amqp_lock,
                                                                :destination => reply_to,
                                                                :headers => headers))
    response = ResponseMessage.new(:id => msg.msg_id, :result => result, :headers => headers)
    publish response.to_s, :routing_key => reply_to
  end

  def handle_response(message)
    msg    = ResponseMessage.new(:message => message, :headers => @message_headers)
    res = err = nil
    begin
      res = Dispatcher.handle_response(msg.result)
    rescue Exception => e
      err = e
    end

    @response_lock.synchronize{
      @result = [res]
      @result << err if !err.nil?
      @response_cv.signal
    }
  end

  public

  # initialize the node w/ the specified params
  def initialize(args = {})
     super(args)
     @broker    = args[:broker]
     @connection_event_handlers = {:closed => [], :error => []}
     @response_lock = Mutex.new
     @response_cv = ConditionVariable.new
  end

  # Initialize the amqp subsystem
  def init_node
     return unless @conn.nil? || !@conn.connected?
     @conn = AMQP.connect(:host => @broker)
     @conn.on_tcp_connection_failure { puts "OTCF #{@node_id}" }

     ### connect to qpid broker
     @channel = AMQP::Channel.new(@conn)

     # qpid constructs that will be created for node
     @queue_name  = "#{@node_id.to_s}-queue"
     @queue       = @channel.queue(@queue_name, :auto_delete => true)
     @exchange    = @channel.default_exchange

     @listening = false
     @disconnected = false

     @exchange.on_return do |basic_return, metadata, payload|
         puts "#{payload} was returned! reply_code = #{basic_return.reply_code}, reply_text = #{basic_return.reply_text}"
         @disconnected = true # FIXME member will be set on wrong class
         connection_event(:error)
         connection_event(:closed)
     end
  end

  # publish a message using the amqp exchange
  def publish(*args)
    raise RJR::Errors::ConnectionError.new("client unreachable") if @disconnected
    @exchange.publish *args
  end

  # subscribe to messages using the amqp queue
  def subscribe(*args, &bl)
    return if @listening
    @listening = true
    @queue.subscribe do |metadata, msg|
      bl.call metadata, msg
    end
  end

  def wait_for_result(message)
    res = nil
    @response_lock.synchronize{
      @response_cv.wait @response_lock
      res = @result
    }
    return res
  end

  # register connection event handler
  def on(event, &handler)
    if @connection_event_handlers.keys.include?(event)
      @connection_event_handlers[event] << handler
    end
  end

  # run connection event handlers for specified event
  # TODO these are only run when we fail to send message to queue, need to detect when that queue is shutdown & other events
  def connection_event(event)
    if @connection_event_handlers.keys.include?(event)
      @connection_event_handlers[event].each { |h|
        h.call self
      }
    end
  end

  # Instruct Node to start listening for and dispatching rpc requests
  def listen
    em_run do
      init_node

      # start receiving messages
      subscribe { |metadata, msg|
        handle_message(metadata, msg)
      }
    end
  end

  # Instructs node to send rpc request, and wait for / return response
  def invoke_request(routing_key, rpc_method, *args)
    message = RequestMessage.new :method => rpc_method,
                                 :args   => args,
                                 :headers => @message_headers
    em_run do
      init_node

      # begin listening for result
      subscribe { |metadata, msg|
        handle_message(metadata, msg)
      }

      publish message.to_s, :routing_key => routing_key, :reply_to => @queue_name
    end

    result = wait_for_result(message)
    self.stop
    self.join unless self.em_running?

    if result.size > 1
      raise result[1]
    end
    return result.first
  end

end
end
