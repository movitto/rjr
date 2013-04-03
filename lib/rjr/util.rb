# High level rjr utility mechanisms
#
# Copyright (C) 2013 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

module RJR

# Module to encapsulate plugins containing rjr methods to
# be registered with the dispatcher
#
# Plugins should be instance variables defined in
# the RJR::Methods module, set to the lambda method handlers
#
# module RJR::Methods
#   # prefix = 'rjr_'
#   @rjr_stress = lambda { |*args|
#     # rjr method implementation
#   }
# end
module Methods
  # Loads and defines rjr test methods from the dirs in the specified path
  def self.load(path, prefix = '')
    path.split(':').each { |methods_dir|
      Dir.glob(File.join(methods_dir, 'methods', '*')).each { |md|
        require md
      }
    }

    RJR::Methods.instance_variables.each { |iv|
      if iv.to_s =~ /#{prefix}(.*)/
        #puts "Registering #{$1}"
        RJR::Dispatcher.add_handler($1, &RJR::Methods.instance_variable_get(iv))
      end
    }
  end
end

# Module to encapsulate plugins containing preformatted rjr messages
#
# Plugins should reside in the specified dirs and should contain
# attribute definitions in the RJR::Messages module namespace idenfied with
# 'rjr_<msg_id>', eg
#
# module RJR::Messages
#   @rjr_stress = { :method => 'stress',
#                   :params => ["<CLIENT_ID>"],
#                   :result => lambda { |r| r == 'foobar' } }
# end
# 
module Messages
  def self.load(path)
    @messages = {}
    path.split(':').each { |messages_dir|
      Dir.glob(File.join(messages_dir, 'messages', '*')).each { |md|
        require md
      }
    }

    RJR::Messages.instance_variables.each { |iv|
      if iv.to_s =~ /rjr_(.*)/
        @messages[$1] = RJR::Messages.instance_variable_get(iv)
      end
    }
  end

  def self.get(id)
    @messages[id]
  end

  def self.rand_msg
    @messages[@messages.keys[rand(@messages.keys.size)]]
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
    # TODO allow selection of node?
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
