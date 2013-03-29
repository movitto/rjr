# Common methods for the rjr test harness


# Module to encapsulate rjr method plugins.
#
# Plugins should be instance variables defined in
# the RJRMethods module, set to the lambda method handlers
#
# module RJRMethods
#   # prefix = 'rjr_'
#   @rjr_stress = lambda { |*args|
#     # rjr method implementation
#   }
# end
module RJRMethods
  # Loads and defines rjr test methods from the specified methods_dir
  def self.load(methods_dir, prefix = '')
    Dir.glob(File.join(methods_dir, '*')).each { |md|
      require md
    }

    RJRMethods.instance_variables.each { |iv|
      if iv.to_s =~ /#{prefix}(.*)/
        #puts "Registering #{$1}"
        RJR::Dispatcher.add_handler($1, &RJRMethods.instance_variable_get(iv))
      end
    }
  end
end

# Module to encapsulate rjr message plugins
#
# Plugins should reside in the specified messages_dir and should contain
# attribute definitions in the RJRMessages module namespace idenfied with
# 'rjr_<msg_id>', eg
#
# module RJRMessages
#   @rjr_stress = { :method => 'stress',
#                   :params => ["<CLIENT_ID>"],
#                   :result => lambda { |r| r == 'foobar' } }
# end
# 
module RJRMessages
  def self.load(messages_dir)
    @messages = {}
    Dir.glob(File.join(messages_dir, '*')).each { |md|
      require md
    }

    RJRMessages.instance_variables.each { |iv|
      if iv.to_s =~ /rjr_(.*)/
        @messages[$1] = RJRMessages.instance_variable_get(iv)
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

# Class to encapsule rjr node
class RJRNode
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
