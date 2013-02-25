# RJR AMQP Endpoint
#
# Implements the RJR::Node interface to satisty JSON-RPC requests over the AMQP protocol
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'amqp'
require 'thread'
require 'rjr/node'
require 'rjr/message'

module RJR

# AMQP node callback interface, used to invoke json-rpc methods on a
# remote node which previously invoked a method on the local one.
#
# After a node sends a json-rpc request to another, the either node may send
# additional requests to each other via amqp through this callback interface
# until the queues are closed
class AMQPNodeCallback

  # AMQPNodeCallback initializer
  # @param [Hash] args the options to create the amqp node callback with
  # @option args [AMQPNode] :node amqp node used to send/receive messages
  # @option args [String]   :destination name of the queue to invoke callbacks on
  def initialize(args = {})
    @node        = args[:node]
    @destination = args[:destination]
  end

  # Implementation of {RJR::NodeCallback#invoke}
  def invoke(callback_method, *data)
    msg = RequestMessage.new :method => callback_method, :args => data, :headers => @message_headers
    @node.publish msg.to_s, :routing_key => @destination, :mandatory => true
  end
end

# AMQP node definition, implements the {RJR::Node} interface to
# listen for and invoke json-rpc requests over
# {http://en.wikipedia.org/wiki/Advanced_Message_Queuing_Protocol AMQP}.
#
# Clients should specify the amqp broker to connect to when initializing
# a node and specify the remote queue when invoking requests.
#
# @example Listening for json-rpc requests over amqp
#   # register rjr dispatchers (see RJR::Dispatcher)
#   RJR::Dispatcher.add_handler('hello') { |name|
#     "Hello #{name}!"
#   }
#
#   # initialize node, listen, and block
#   server = RJR::AMQPNode.new :node_id => 'server', :broker => 'localhost'
#   server.listen
#   server.join
#
# @example Invoking json-rpc requests over amqp
#   client = RJR::AMQPNode.new :node_id => 'client', :broker => 'localhost'
#   puts client.invoke_request('server-queue', 'hello', 'mo') # the queue name is set to "#{node_id}-queue"
class  AMQPNode < RJR::Node
  RJR_NODE_TYPE = :amqp

  private

  # Internal helper, handle message pulled off queue
  def handle_message(metadata, msg)
    if RequestMessage.is_request_message?(msg)
      reply_to = metadata.reply_to
      @thread_pool << ThreadPoolJob.new { handle_request(reply_to, msg) }

    elsif ResponseMessage.is_response_message?(msg)
      handle_response(msg)

    end
  end

  # Internal helper, handle request message pulled off queue
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
                                                                :destination => reply_to,
                                                                :headers => headers))
    response = ResponseMessage.new(:id => msg.msg_id, :result => result, :headers => headers)
    publish response.to_s, :routing_key => reply_to
  end

  # Internal helper, handle response message pulled off queue
  def handle_response(message)
    msg    = ResponseMessage.new(:message => message, :headers => @message_headers)
    res = err = nil
    begin
      res = Dispatcher.handle_response(msg.result)
    rescue Exception => e
      err = e
    end

    @response_lock.synchronize{
      result = [msg.msg_id, res]
      result << err if !err.nil?
      @responses << result
      @response_cv.signal
    }
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
     #@disconnected = false

     @exchange.on_return do |basic_return, metadata, payload|
         puts "#{payload} was returned! reply_code = #{basic_return.reply_code}, reply_text = #{basic_return.reply_text}"
         #@disconnected = true # FIXME member will be set on wrong class
         connection_event(:error)
         connection_event(:closed)
     end
  end

  # Internal helper, block until response matching message id is received
  def wait_for_result(message)
    res = nil
    while res.nil?
      @response_lock.synchronize{
        @response_cv.wait @response_lock
        # FIXME throw err if more than 1 match found
        res = @responses.select { |response| message.msg_id == response.first }.first
        unless res.nil?
          @responses.delete(res)
        else
          # we can't just go back to waiting for message here, need to give
          # other nodes a chance to check it first
          @response_cv.signal
          @response_check_cv.wait @response_lock
        end
        @response_check_cv.signal
      }
    end
    return res
  end

  # Internal helper, run connection event handlers for specified event
  # TODO these are only run when we fail to send message to queue, need to detect when that queue is shutdown & other events
  def connection_event(event)
    if @connection_event_handlers.keys.include?(event)
      @connection_event_handlers[event].each { |h|
        h.call self
      }
    end
  end

  # Internal helper, subscribe to messages using the amqp queue
  def subscribe(*args, &bl)
    return if @listening
    @amqp_lock.synchronize {
      @listening = true
      @queue.subscribe do |metadata, msg|
        bl.call metadata, msg
      end
    }
    nil
  end


  public

  # AMQPNode initializer
  # @param [Hash] args the options to create the amqp node with
  # @option args [String] :broker the amqp message broker which to connect to
  def initialize(args = {})
     super(args)
     @broker    = args[:broker]
     @connection_event_handlers = {:closed => [], :error => []}
     @response_lock = Mutex.new
     @response_cv   = ConditionVariable.new
     @response_check_cv   = ConditionVariable.new
     @responses     = []
     @amqp_lock     = Mutex.new
  end

  # Publish a message using the amqp exchange (*do* *not* *use*).
  #
  # XXX hack should be private, declared publically so as to be able to be used by {RJR::AMQPNodeCallback}
  def publish(*args)
    @amqp_lock.synchronize {
      #raise RJR::Errors::ConnectionError.new("client unreachable") if @disconnected
      @exchange.publish *args
    }
    nil
  end

  # Register connection event handler
  # @param [:error, :close] event the event to register the handler for
  # @param [Callable] handler block param to be added to array of handlers that are called when event occurs
  # @yield [AMQPNode] self is passed to each registered handler when event occurs
  def on(event, &handler)
    if @connection_event_handlers.keys.include?(event)
      @connection_event_handlers[event] << handler
    end
  end

  # Instruct Node to start listening for and dispatching rpc requests.
  #
  # Implementation of {RJR::Node#listen}
  def listen
    em_run do
      init_node

      # start receiving messages
      subscribe { |metadata, msg|
        handle_message(metadata, msg)
      }
    end
  end

  # Instructs node to send rpc request, and wait for and return response
  # @param [String] routing_key destination queue to send request to
  # @param [String] rpc_method json-rpc method to invoke on destination
  # @param [Array] args array of arguments to convert to json and invoke remote method wtih
  # @return [Object] the json result retrieved from destination converted to a ruby object
  # @raise [Exception] if the destination raises an exception, it will be converted to json and re-raised here 
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

    # TODO optional timeout for response ?
    result = wait_for_result(message)

    # need to disable the timeout if there is one, the result came within timeout
    @@em_thread[:running] = false
    @@em_thread[:first_cycle_passed] = false

    #self.stop
    #self.join unless self.em_running?

    if result.size > 2
      raise result[2]
    end
    return result[1]
  end

end
end
