# RJR Easy Node
#
# Implements the RJR::Node client interface to
# issue JSON-RPC requests over a variety of protocols
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'rjr/nodes/tcp'
require 'rjr/nodes/ws'
require 'rjr/nodes/web'
require 'rjr/nodes/amqp'
require 'rjr/nodes/multi'
require 'rjr/node'

module RJR
module Nodes

# Easy node definition
class Easy < RJR::Node
  private

  def get_node(dst)
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

      end
    end

    return @multi_node.nodes.find { |n| n.is_a?(type) } unless type.nil?
    nil
  end

  public

  # initializer
  # @param [Hash] args the options to create the node with
  def initialize(args = {})
     super(args)

     nodes = []
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
  def send_msg(data, connection)
  # TODO
  end

  # Instruct Nodes to start listening for and dispatching rpc requests
  #
  # Implementation of {RJR::Node#listen}
  def listen
    @multi_node.listen
  end

  def invoke(dst, rpc_method, *args)
    n = get_node(dst)
    # TODO raise exception if n.nil?
    n.invoke dst, rpc_method, *args
  end

  def notify(dst, rpc_method, *args)
    n = get_node(dst)
    n.notify dst, rpc_method, *args
  end

  # Stop node on the specified signal
  def stop_on(signal)
    Signal.trap(signal) {
      @multi_node.stop
    }
    self
  end
end

end # module Nodes
end # module RJR
