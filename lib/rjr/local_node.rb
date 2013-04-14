# RJR Local Endpoint
#
# Implements the RJR::Node interface to satisty JSON-RPC requests via local method calls
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'rjr/node'
require 'rjr/message'
require 'rjr/dispatcher'

module RJR

# Local node callback interface, used to invoke local json-rpc method handlers
class LocalNodeCallback
  # LocalNodeCallback initializer
  # @param [Hash] args the options to create the local node callback with
  # @option args [LocalNode] :node local node used to send/receive messages
  def initialize(args = {})
    @node        = args[:node]
  end

  # Implementation of {RJR::NodeCallback#invoke}
  def invoke(callback_method, *data)
    @node.em_run {
      # TODO any exceptions from handler will propagate here, surround w/ begin/rescue block
      # TODO support local_node 'disconnections'
      @node.local_dispatch(callback_method, *data)
    }
  end
end

# Local node definition, implements the {RJR::Node} interface to
# listen for and invoke json-rpc requests via local handlers
#
# This is useful for situations in which you would like to invoke registered
# json-rpc handlers locally, enforcing the same constraints as
# you would on a json-rpc request coming in remotely.
#
# @example Listening for and dispatching json-rpc requests locally
#   RJR::Dispatcher.add_handler('hello') { |name|
#     @rjr_node_type == :local ? "Hello superuser #{name}" : "Hello #{name}!"
#   }
#
#   # initialize node and invoke request
#   node = RJR::LocalNode.new :node_id => 'node'
#   node.invoke_request('hello', 'mo')
#
class LocalNode < RJR::Node
  RJR_NODE_TYPE = :local

  # allows clients to override the node type for the local node
  attr_accessor :node_type

  # Helper method to locally dispatch method/args
  #
  # TODO would like to make private but needed in LocalNodeCallback
  def local_dispatch(rpc_method, *args)
    # create request from args
    0.upto(args.size).each { |i| args[i] = args[i].to_s if args[i].is_a?(Symbol) }
    message = RequestMessage.new :method => rpc_method,
                                 :args   => args,
                                 :headers => @message_headers

    # here we serialize / unserialze messages to/from json to
    # ensure local node complies to same json-rpc restrictions as other nodes
    message = RequestMessage.new :message => message.to_s,
                                 :headers => @message_headers

    result = Dispatcher.dispatch_request(message.jr_method,
                                         :method_args => message.jr_args,
                                         :headers => @message_headers,
                                         :rjr_node      => self,
                                         :rjr_node_id   => @node_id,
                                         :rjr_node_type => @node_type,
                                         :rjr_callback =>
                                           LocalNodeCallback.new(:node => self,
                                                                 :headers => @message_headers))

    # create response message from result
    response = ResponseMessage.new(:id => message.msg_id,
                                   :result => result,
                                   :headers => @message_headers)

    # same comment on serialization/unserialization as above
    response = ResponseMessage.new(:message => response.to_s,
                                   :headers => @message_headers)

    response
  end

  # LocalNode initializer
  # @param [Hash] args the options to create the local node with
  def initialize(args = {})
     super(args)
     @node_type = RJR_NODE_TYPE
  end

  # register connection event handler,
  # *note* Until we support manual disconnections of the local node, we don't have to do anything here
  #
  # @param [:error, :close] event the event to register the handler for
  # @param [Callable] handler block param to be added to array of handlers that are called when event occurs
  # @yield [LocalNode] self is passed to each registered handler when event occurs
  def on(event, &handler)
    # TODO raise error (for the time being)?
  end

  # Instruct Node to start listening for and dispatching rpc requests
  #
  # Currently does nothing as method handlers can be invoked directly upon invoke_request
  def listen
  end

  # Instructs node to send rpc request, and wait for and return response
  # @param [String] rpc_method json-rpc method to invoke on destination
  # @param [Array] args array of arguments to convert to json and invoke remote method wtih
  # @return [Object] the json result retrieved from destination converted to a ruby object
  # @raise [Exception] if the destination raises an exception, it will be converted to json and re-raised here 
  def invoke_request(rpc_method, *args)
    # will block until message is published
    published_l = Mutex.new
    published_c = ConditionVariable.new

    response  = nil

    em_run {
      res = local_dispatch(rpc_method, *args) 

      # TODO run in thread?
      published_l.synchronize {
        response = res
        published_c.signal
      }
    }

    published_l.synchronize { published_c.wait published_l if response.nil? }

    return Dispatcher.handle_response(response.result)
  end

  # Instructs node to send rpc notification (immediately returns / no response is generated)
  #
  # @param [String] rpc_method json-rpc method to invoke on destination
  # @param [Array] args array of arguments to convert to json and invoke remote method wtih
  def send_notification(rpc_method, *args)
    # will block until message is published
    published_l = Mutex.new
    published_c = ConditionVariable.new

    invoked = false

    em_run {
      # TODO run in thread?
      local_dispatch(rpc_method, *args)
      published_l.synchronize { invoked = true ; published_c.signal }
    }

    published_l.synchronize { published_c.wait published_l unless invoked }
    nil
  end


end
end
