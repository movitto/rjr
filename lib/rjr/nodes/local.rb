# RJR Local Endpoint
#
# Implements the RJR::Node interface to satisty JSON-RPC requests via local method calls
#
# Copyright (C) 2012-2013 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'rjr/node'
require 'rjr/messages'

module RJR
module Nodes

# Local node definition, implements the {RJR::Node} interface to
# listen for and invoke json-rpc requests via local handlers
#
# This is useful for situations in which you would like to invoke registered
# json-rpc handlers locally, enforcing the same constraints as
# you would on a json-rpc request coming in remotely.
#
# *Note* this only dispatches to the methods defined on the local dispatcher!
#
# If you have two local nodes, they will have seperate dispatchers unless you
# assign them the same object (eg node2.dispatcher = node1.dispatcher or
# node2 = new RJR::Nodes::Local.new(:dispatcher :=> node1.dispatcher))
#
# @example Listening for and dispatching json-rpc requests locally
#   # initialize node
#   node = RJR::Nodes::Local.new :node_id => 'node'
#
#   node.dispatcher.handle('hello') do |name|
#     @rjr_node_type == :local ? "Hello superuser #{name}" : "Hello #{name}!"
#   end
#
#   # invoke request
#   node.invoke('hello', 'mo')
#
class Local < RJR::Node
  RJR_NODE_TYPE = :local
  PERSISTENT_NODE = true
  INDIRECT_NODE = false

  # allows clients to override the node type for the local node
  attr_accessor :node_type

  # Nodes::Local initializer
  # @param [Hash] args the options to create the local node with
  def initialize(args = {})
     super(args)
     @node_type = RJR_NODE_TYPE
  end

  def to_s
    "RJR::Nodes::Local<#{@node_id}>"
  end

  # Send data using specified connection.
  #
  # Simply dispatch local notification.
  #
  # Implementation of RJR::Node#send_msg
  def send_msg(msg, connection)
    # ignore response message
    unless Messages::Response.is_response_message?(msg)
      launch_request(msg, true) # .join?
    end
  end

  # Instruct Nodes to start listening for and dispatching rpc requests
  #
  # Implementation of RJR::Node#listen
  def listen
    # do nothing
    self
  end

  # Helper to launch request in new thread
  #
  # This needs to happen so that each request runs in its own context
  # (or close to it, globals will still be available, but locks will
  #  not be locally held, etc)
  def launch_request(req, notification)
    Thread.new(req,notification) { |req,notification|
      res = handle_request(req, notification, nil)
      handle_response(res.to_s) unless res.nil?
    }
  end

  # Instructs node to send rpc request, and wait for and return response
  #
  # Implementation of RJR::Node#invoke
  #
  # If strictly confirming to other nodes, this would use event machine to launch
  # a thread pool job to dispatch request and block on result.
  # Optimized for performance reasons but recognize that the semantics of using
  # the local node will be somewhat different.
  #
  # @param [String] rpc_method json-rpc method to invoke on destination
  # @param [Array] args array of arguments to convert to json and invoke remote method with
  # @return [Object] the json result retrieved from destination converted to a ruby object
  # @raise [Exception] if the destination raises an exception, it will be converted to json and re-raised here 
  def invoke(rpc_method, *args)
    0.upto(args.size).each { |i| args[i] = args[i].to_s if args[i].is_a?(Symbol) }
    message = Messages::Request.new(:method => rpc_method,
                                    :args   => args,
                                    :headers => @message_headers)
    launch_request(message.to_s, false)

    # TODO optional timeout for response ?
    res = wait_for_result(message)

    if res.size > 2
      raise Exception, res[2]
    end
    return res[1]
  end

  # Instructs node to send rpc notification (immediately returns / no response is generated)
  #
  # Implementation of RJR::Node#notify
  #
  # Same performance comment as invoke_request above
  #
  # @param [String] rpc_method json-rpc method to invoke on destination
  # @param [Array] args array of arguments to convert to json and invoke remote method wtih
  def notify(rpc_method, *args)
    0.upto(args.size).each { |i| args[i] = args[i].to_s if args[i].is_a?(Symbol) }
    message = Messages::Notification.new(:method => rpc_method,
                                         :args   => args,
                                         :headers => @message_headers)
    launch_request(message.to_s, true) #.join ?
    nil
  end


end # class Local

end # module Nodes
end # module RJR
