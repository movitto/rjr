require 'rjr/dispatcher'
require 'rjr/node'

module RJR
  describe Node do
    before(:all) do
      # was made public in ruby 1.9
      if RUBY_VERSION < "1.9"
        RJR::Node.public_class_method(:class_variable_get)
      end
    end

    describe "::persistent?" do
      context "PERSISTENT_NODE is defined and true" do
        it "returns true" do
          new_node = Class.new(Node)
          new_node.const_set(:PERSISTENT_NODE, true)
          new_node.should be_persistent
        end
      end

      context "PERSISTENT_NODE is not defined or returns false" do
        it "returns false" do
          Node.should_not be_persistent
        end
      end
    end

    describe "#persistent?" do
      context "instance of a persistent node" do
        it "returns true" do
          new_node = Class.new(Node)
          new_node.const_set(:PERSISTENT_NODE, true)
          new_node.new.should be_persistent
        end
      end

      context "not an instance of a persistent node" do
        it "returns false" do
          Node.new.should_not be_persistent
        end
      end
    end

    it "should initialize properly from params" do
      d = Dispatcher.new
      node = Node.new :node_id => 'foobar',
                      :headers => {:h => 123},
                      :dispatcher => d
      node.node_id.should == 'foobar'
      node.message_headers[:h].should == 123
      node.dispatcher.should == d
    end

    it "should create a new dispatcher" do
      node = Node.new
      node.dispatcher.should_not be_nil
      node.dispatcher.class.should == Dispatcher
    end

    it "should start the thread pool" do
      node = Node.new
      node.class.class_variable_get(:@@tp).should be_running
    end

    it "should start event machine" do
      EventMachine.stop_event_loop
      node = Node.new
      EventMachine.reactor_running?.should be_true
    end

    it "should halt the thread pool" do
      node = Node.new
      node.halt.join
      node.class.class_variable_get(:@@tp).should_not be_running
    end

    it "should halt event machine" do
      node = Node.new
      node.halt.join
      EventMachine.reactor_running?.should be_false
    end

    it "should handle connection events" do
      node = Node.new
      closed = false
      error = false
      node.on :closed do
        closed = true
      end
      node.on :error do
        error = true
      end
      node.send(:connection_event, :error)
      error.should be_true

      node.send(:connection_event, :closed)
      closed.should be_true
    end

    it "should handle request messages"
    it "should handle notification messages"
    it "should handle response messages"
    it "should block until reponse is received"
  end

  describe NodeCallback do
    it "should send notifications"
  end
end
