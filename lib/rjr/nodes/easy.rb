# RJR Easy Node
#
# Implements the RJR::Node client interface to
# issue JSON-RPC requests over a variety of protocols
#
# Copyright (C) 2013 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'rjr/nodes/tcp'
require 'rjr/nodes/ws'
require 'rjr/nodes/web'
require 'rjr/nodes/amqp'
require 'rjr/nodes/multi'
require 'rjr/node'

module RJR
module Nodes

# Easy node definition.
#
# Clients should specify the transports that they would like to use
# and their relevant config upon instantating this call. After which
# invocations and notifications will be routed via the correct transport
# depending on the format of the destination.
#
# All nodes managed locally will share the same dispatcher so that json-rpc methods
# only need to be registered once, with the multi-node itself.
#
# @example invoking requests via multiple protocols
#   easy = RJR::Nodes::Easy.new :tcp  => { :host   => 'localhost', :port => 8999 },
#                               :amqp => { :broker => 'localhost' }
#
#   easy.invoke 'tcp://localhost:9000/', 'hello world'
#   # => sent via tcp
#
#   easy.notify 'dest-queue', 'hello world'
#   # => sent via amqp
#
class Easy < RJR::Node
  # Publically available helper, retrieve the rjr node type
  # based on dst format
  def self.node_type_for(dst)
    type = nil
    if dst.is_a?(String)
      if /tcp:\/\/.*/      =~ dst ||
         /jsonrpc:\/\/.*/  =~ dst ||
         /json-rpc:\/\/.*/ =~ dst
          type = RJR::Nodes::TCP

      elsif /ws:\/\/.*/    =~ dst
        type = RJR::Nodes::WS

      elsif /http:\/\/.*/   =~ dst
        type = RJR::Nodes::Web

      elsif /.*-queue$/   =~ dst
        type = RJR::Nodes::AMQP

      # else # TODO
      # type = RJR::Nodes::Local

      end
    end

    type
  end

  private

  # Internal helper, retrieved the registered node depending on
  # the type retrieved from the dst. If matching node type can't
  # be found, nil is returned
  def get_node(dst)
    type = self.class.node_type_for(dst)

    # TODO also add optional mechanism to class to load nodes of
    # new types on the fly as they are needed
    return @multi_node.nodes.find { |n| n.is_a?(type) } unless type.nil?

    nil
  end

  public

  # Easy Node initializer
  # @param [Hash] args the options to create the node with
  # @option args [Hash] :amqp options to create the amqp node with
  # @option args [Hash] :ws options to create the ws node with
  # @option args [Hash] :tcp options to create the ws node with
  # @option args [Hash] :web options to create the web node with
  def initialize(args = {})
     super(args)

     nodes = args[:nodes] || []
     args.keys.each { |n|
       node = 
       case n
       when :amqp then
         RJR::Nodes::AMQP.new  args[:amqp].merge(args)
       when :ws then
         RJR::Nodes::WS.new    args[:ws].merge(args)
       when :tcp then
         RJR::Nodes::TCP.new   args[:tcp].merge(args)
       when :web then
         RJR::Nodes::Web.new   args[:web].merge(args)
       end

       if node
         nodes << node
       end
     }

     @multi_node = RJR::Nodes::Multi.new :nodes => nodes
     @dispatcher = @multi_node.dispatcher
  end

  # Send data using specified connection
  #
  # Implementation of RJR::Node#send_msg
  def send_msg(data, connection)
  # TODO
  end

  # Instruct Nodes to start listening for and dispatching rpc requests
  #
  # Implementation of RJR::Node#listen
  def listen
    @multi_node.listen
  end

  # Instructs node to send rpc request, and wait for and return response.
  #
  # Implementation of RJR::Node#invoke
  #
  # @param [String] dst destination send request to
  # @param [String] rpc_method json-rpc method to invoke on destination
  # @param [Array] args array of arguments to convert to json and invoke remote method wtih
  # @return [Object] the json result retrieved from destination converted to a ruby object
  # @raise [Exception] if the destination raises an exception, it will be converted to json and re-raised here 
  def invoke(dst, rpc_method, *args)
    n = get_node(dst)
    # TODO raise exception if n.nil?
    n.invoke dst, rpc_method, *args
  end

  # Instructs node to send rpc notification (immadiately returns / no response is generated)
  #
  # Implementation of RJR::Node#notify
  #
  # @param [String] dst destination to send notification to
  # @param [String] rpc_method json-rpc method to invoke on destination
  # @param [Array] args array of arguments to convert to json and invoke remote method wtih
  def notify(dst, rpc_method, *args)
    n = get_node(dst)
    n.notify dst, rpc_method, *args
  end

  # Stop node on the specified signal
  #
  # @param [Singnal] signal signal to stop the node on
  # @return self
  def stop_on(signal)
    Signal.trap(signal) {
      @multi_node.stop
    }
    self
  end
end

end # module Nodes
end # module RJR
