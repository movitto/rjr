# RJR Local Endpoint
#
# Implements the RJR::Node interface to satisty JSON-RPC requests via local method calls
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'rjr/node'
require 'rjr/message'
require 'rjr/dispatcher'
require 'rjr/errors'

module RJR
module Nodes

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
class Local < RJR::Node
  RJR_NODE_TYPE = :local

  # allows clients to override the node type for the local node
  attr_accessor :node_type

  # LocalNode initializer
  # @param [Hash] args the options to create the local node with
  def initialize(args = {})
     super(args)
     @node_type = RJR_NODE_TYPE
  end

  # simply dispatch local notification
  def send_msg(msg, connection)
    # ignore response message
    unless msg.is_a?(ResponseMessage)
      handle_request(msg, true, nil)
    end
  end

  def listen
    # do nothing
    self
  end

  # Instructs node to send rpc request, and wait for and return response
  #
  # If strictly confirming to other nodes, use event machine to launch
  # a thread pool job to dispatch request and block on result.
  # Optimized for performance reasons but recognize the semantics of using
  # the local node will be somewhat different.
  #
  # @param [String] rpc_method json-rpc method to invoke on destination
  # @param [Array] args array of arguments to convert to json and invoke remote method wtih
  # @return [Object] the json result retrieved from destination converted to a ruby object
  # @raise [Exception] if the destination raises an exception, it will be converted to json and re-raised here 
  def invoke(rpc_method, *args)
    0.upto(args.size).each { |i| args[i] = args[i].to_s if args[i].is_a?(Symbol) }
    message = RequestMessage.new(:method => rpc_method,
                                 :args   => args,
                                 :headers => @message_headers).to_s
    res = handle_request(message, false, nil)
    return @dispatcher.handle_response(res.result)
  end

  # Instructs node to send rpc notification (immediately returns / no response is generated)
  #
  # Same performance comment as invoke_request above
  #
  # @param [String] rpc_method json-rpc method to invoke on destination
  # @param [Array] args array of arguments to convert to json and invoke remote method wtih
  def notify(rpc_method, *args)
    # TODO run in thread & immediately return?
    begin
      0.upto(args.size).each { |i| args[i] = args[i].to_s if args[i].is_a?(Symbol) }
      message = NotificationMessage.new(:method => rpc_method,
                                        :args   => args,
                                        :headers => @message_headers).to_s
      handle_request(message, true, nil)
    rescue
    end
    nil
  end


end # class Local

end # module Nodes
end # module RJR
