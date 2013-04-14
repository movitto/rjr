# High level rjr utility mechanisms
#
# Copyright (C) 2013 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'rjr/dispatcher'

module RJR

# Mixin providing utility methods to define rjr methods and messages
module Definitions
  # Define one or more rjr methods, parameters should be in the form
  #   :id => Callable
  #
  # id may be a single id or an array of them
  def rjr_method(args = {})
    args.each { |k, v|
      RJR::Dispatcher.add_handler(k.to_s, &v)
    }
    nil
  end

  # Define/retrieve rjr messages. When defining pass a hash
  # of mesasge ids to options to use in the defintions, eg
  #   :id  => { :foo => :bar }
  #
  # When retrieving simply specify the id
  def rjr_message(args={})
    if args.is_a?(Hash)
      args.each { |k,v|
        RJR::Definitions.message(k.to_s, v)
      }
      nil
    else
      RJR::Definitions.message(args.to_s)
    end
  end

  # Helper providing access to messages
  def self.message(k, v=nil)
    @rjr_messages ||= {}
    @rjr_messages[k] = v unless v.nil?
    @rjr_messages[k]
  end

  # Reset message registry
  def self.reset
    # TODO also invoke 'Dispatcher.init_handlers' ?
    @rjr_messages = {}
  end

  # Generate / return random message. Optionally specify the transport which
  # the message must accept
  def self.rand_msg(transport = nil)
    @rjr_messages ||= {}
    messages = @rjr_messages.select { |mid,m| m[:transports].nil? || transport.nil? ||
                                              m[:transports].include?(transport)    }
    messages[messages.keys[rand(messages.keys.size)]]
  end
end

# Class to encapsulate any number of rjr nodes
class EasyNode
  def initialize(node_args = {})
    nodes = node_args.keys.collect { |n|
              case n
              when :amqp then
                RJR::AMQPNode.new  node_args[:amqp]
              when :ws then
                RJR::WSNode.new    node_args[:ws]
              when :tcp then
                RJR::TCPNode.new   node_args[:tcp]
              when :www then
                RJR::WebNode.new   node_args[:www]
              end
            }
    @multi_node = RJR::MultiNode.new :nodes => nodes
  end

  def invoke_request(dst, method, *params)
    # TODO allow selection of node, eg automatically deduce which node type to use from 'dst'
    @multi_node.nodes.first.invoke_request(dst, method, *params)
  end

  # Stop node on the specified signal
  def stop_on(signal)
    Signal.trap(signal) {
      @multi_node.stop
    }
    self
  end

  def listen
    @multi_node.listen
    self
  end

  def join
    @multi_node.join
    self
  end
end

end # module RJR
