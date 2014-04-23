# RJR AMQP Node
#
# Implements the RJR::Node interface to satisty JSON-RPC requests over the AMQP protocol
#
# Copyright (C) 2012-2013 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

skip_module = false
begin
require 'amqp'
rescue LoadError
  skip_module = true
end

if skip_module
# TODO output: "amqp gem could not be loaded, skipping amqp node definition"
require 'rjr/nodes/missing'
RJR::Nodes::AMQP = RJR::Nodes::Missing

else
require 'thread'
require 'rjr/node'
require 'rjr/messages'

module RJR
module Nodes

# AMQP node definition, implements the {RJR::Node} interface to
# listen for and invoke json-rpc requests over the
# Advanced Message Queuing Protocol.
#
# Clients should specify the amqp broker to connect to when initializing
# a node and specify the remote queue when invoking requests.
#
# @example Listening for json-rpc requests over amqp
#   # initialize node,
#   server = RJR::Nodes::AMQP.new :node_id => 'server', :broker => 'localhost'
#
#   # register rjr dispatchers (see RJR::Dispatcher)
#   server.dispatcher.handle('hello') do |name|
#     "Hello #{name}!"
#   end
#
#   # listen, and block
#   server.listen
#   server.join
#
# @example Invoking json-rpc requests over amqp
#   client = RJR::Nodes::AMQP.new :node_id => 'client', :broker => 'localhost'
#   puts client.invoke('server-queue', 'hello', 'mo') # the queue name is set to "#{node_id}-queue"
#
class AMQP < RJR::Node
  RJR_NODE_TYPE = :amqp
  PERSISTENT_NODE = true
  INDIRECT_NODE = true

  private

  def amqp_options
    opts = {}
    opts[:host]  = @host  if @host
    opts[:port]  = @port  if @port
    opts[:vhost] = @vhost if @vhost
    opts[:user]  = @user  if @user
    opts[:pass]  = @pass  if @pass
    opts[:ssl]   = @ssl   if @ssl
    opts
  end

  # Internal helper, initialize the amqp subsystem
  def init_node(&on_init)
     if !@conn.nil? && @conn.connected?
       on_init.call
       return
     end

     @conn = ::AMQP.connect(amqp_options) do |conn|
       ::AMQP.connection = conn # XXX not sure why this is needed but the amqp
                                # em interface won't shut down cleanly otherwise

       conn.on_tcp_connection_failure { puts "OTCF #{@node_id}" }

       ### connect to qpid broker
       @channel = ::AMQP::Channel.new(conn)

       # qpid constructs that will be created for node
       @queue_name  = "#{@node_id.to_s}-queue"
       @queue       = @channel.queue(@queue_name, :auto_delete => true)
       @exchange    = @channel.default_exchange

       @listening = false
       #@disconnected = false

       @exchange.on_return do |basic_return, metadata, payload|
           puts "#{payload} was returned! reply_code = #{basic_return.reply_code}, reply_text = #{basic_return.reply_text}"
           #@disconnected = true # FIXME member will be set on wrong class
           # TODO these are only run when we fail to send message to queue,
           # need to detect when that queue is shutdown & other events
           connection_event(:error)
           connection_event(:closed)
       end

       on_init.call
     end
  end

  # Internal helper, subscribe to messages using the amqp queue
  def subscribe
    if @listening
      return
    end

    @amqp_lock.synchronize {
      @listening = true
      @queue.subscribe do |metadata, msg|
        # swap reply to and routing key
        handle_message(msg, {:routing_key => metadata.reply_to, :reply_to => @queue_name})
      end
    }
    nil
  end

  public

  # AMQPNode initializer
  #
  # @param [Hash] args the options to create the amqp node with
  # @option args [String] :broker the amqp message broker which to connect to
  def initialize(args = {})
     super(args)
     @host          = args[:host] || args[:broker]
     @port          = args[:port]
     @vhost         = args[:vhost]
     @user          = args[:user] || args[:username]
     @pass          = args[:pass] || args[:password]
     @ssl           = args[:ssl]
     @amqp_lock     = Mutex.new
  end

  def to_s
    "RJR::Nodes::AMQP<#{@node_id},#{@host},#{@port},#{@vhost},#{@queue_name}>"
  end

  # Publish a message using the amqp exchange
  #
  # Implementation of RJR::Node#send_msg
  def send_msg(msg, metadata, &on_publish)
    @amqp_lock.synchronize {
      #raise RJR::Errors::ConnectionError.new("client unreachable") if @disconnected
      routing_key = metadata[:routing_key]
      reply_to    = metadata[:reply_to]
      @exchange.publish msg,
                        :routing_key => routing_key,
                        :reply_to => reply_to do |*cargs|
        on_publish.call unless on_publish.nil?
      end
    }
    nil
  end

  # Instruct Node to start listening for and dispatching rpc requests.
  #
  # Implementation of RJR::Node#listen
  def listen
    @@em.schedule do
      init_node {
        subscribe # start receiving messages
      }
    end
    self
  end

  # Instructs node to send rpc request, and wait for and return response.
  #
  # Implementation of RJR::Node#invoke
  #
  # Do not invoke directly from em event loop or callback as will block the message
  # subscription used to receive responses
  #
  # @param [String] routing_key destination queue to send request to
  # @param [String] rpc_method json-rpc method to invoke on destination
  # @param [Array] args array of arguments to convert to json and invoke remote method wtih
  # @return [Object] the json result retrieved from destination converted to a ruby object
  # @raise [Exception] if the destination raises an exception, it will be converted to json and re-raised here 
  def invoke(routing_key, rpc_method, *args)
    message = Messages::Request.new :method => rpc_method,
                                    :args   => args,
                                    :headers => @message_headers
    @@em.schedule do
      init_node {
        subscribe # begin listening for result
        send_msg(message.to_s, :routing_key => routing_key, :reply_to => @queue_name)
      }
    end

    # TODO optional timeout for response
    result = wait_for_result(message)

    if result.size > 2
      raise Exception, result[2]
    end
    return result[1]
  end

  # FIXME add method to instruct node to send rpc request, and immediately
  #        return / ignoring response & also add method to collect response
  #        at a later time

  # Instructs node to send rpc notification (immadiately returns / no response is generated)
  #
  # Implementation of RJR::Node#notif}
  #
  # @param [String] routing_key destination queue to send request to
  # @param [String] rpc_method json-rpc method to invoke on destination
  # @param [Array] args array of arguments to convert to json and invoke remote method wtih
  def notify(routing_key, rpc_method, *args)
    # will block until message is published
    published_l = Mutex.new
    published_c = ConditionVariable.new

    invoked = false
    message = Messages::Notification.new :method => rpc_method,
                                         :args   => args,
                                         :headers => @message_headers
    @@em.schedule do
      init_node {
        send_msg(message.to_s, :routing_key => routing_key, :reply_to => @queue_name){
          published_l.synchronize { invoked = true ; published_c.signal }
        }
      }
    end
    published_l.synchronize { published_c.wait published_l unless invoked }
    nil
  end

end # class AMQP

end # module Nodes
end # module RJR 

end # (!skip_module)
