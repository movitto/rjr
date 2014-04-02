require 'rjr/dispatcher'

require 'rjr/node'
require 'rjr/node_callback'

module RJR
  describe NodeCallback do
    describe "#initialize" do
      it "sets node" do
        node = Object.new
        callback = NodeCallback.new :node => node
        callback.node.should == node
      end

      it "sets connection" do
        connection = Object.new
        callback = NodeCallback.new :connection => connection
        callback.connection.should == connection
      end
    end

    describe "#notify" do
      before(:each) do
        @connection = Object.new
        @node       = Node.new :headers => {'msg' => 'headers'}
        @callback  = NodeCallback.new :node => @node,
                                       :connection => @connection
      end

      context "node is not persistent" do
        it "just returns / does not send msg" do
          @node.should_receive(:persistent?).and_return(false)
          @node.should_not_receive(:send_msg)
          @callback.notify('')
        end
      end

      it "sends notification via node" do
        expected = Messages::Notification.new :method  => 'method1',
                                              :args    => ['method', 'args'],
                                              :headers => {'msg' => 'headers'}
        @node.should_not_receive(:send_msg).with(expected.to_s, @connection)
        @callback.notify('msg')
      end
    end
  end
end
