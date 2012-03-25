require 'rjr/node'

describe RJR::Node do
  it "should initialize properly from params" do
    node = RJR::Node.new :node_id => 'foobar',
                         :headers => {:h => 123}
    node.node_id.should == 'foobar'
    node.message_headers[:h].should == 123
    node.instance_variable_get(:@thread_pool).running?.should be_true

    #node.terminate
    #node.instance_variable_get(:@thread_pool).running?.should be_false
  end

  it "should start eventmachine and allow multiple blocks to be invoked in its context" do
    block1_called = false
    block2_called = false

    node = RJR::Node.new :node_id => 'foobar',
                         :headers => {:h => 123}
    node.em_run {
      EventMachine.reactor_running?.should be_true
      block1_called = true
      node.em_run {
        EventMachine.reactor_running?.should be_true
        block2_called = true
        node.halt
      }
    }
    node.join

    block1_called.should be_true
    block2_called.should be_true
  end
end
