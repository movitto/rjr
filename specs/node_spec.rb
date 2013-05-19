require 'rjr/dispatcher'
require 'rjr/node'

module RJR
  describe Node do

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
      ThreadPool.instance.stop.join
      node = Node.new
      ThreadPool.instance.should be_running
    end

    it "should start event machine" do
      EMAdapter.instance.halt.join
      node = Node.new
      EMAdapter.instance.reactor_running?.should be_true
    end

    it "should halt the thread pool" do
      node = Node.new
      node.halt.join
      ThreadPool.instance.should_not be_running
    end

    it "should halt event machine" do
      node = Node.new
      node.halt.join
      EMAdapter.instance.reactor_running?.should be_false
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
