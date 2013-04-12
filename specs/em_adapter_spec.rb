require 'rjr/dispatcher'
require 'rjr/em_adapter'

describe EMManager do
  it "should start and halt the reactor thread" do
    manager = EMManager.new
    manager.start
    EventMachine.reactor_running?.should be_true
    manager.running?.should be_true
    manager.instance_variable_get(:@reactor_thread).should_not be_nil
    rt = manager.instance_variable_get(:@reactor_thread)
    ['sleep', 'run'].should include(manager.instance_variable_get(:@reactor_thread).status)

    manager.start
    rt2 = manager.instance_variable_get(:@reactor_thread)
    rt.should == rt2

    manager.halt
    manager.join
    EventMachine.reactor_running?.should be_false
    manager.running?.should be_false
    manager.instance_variable_get(:@reactor_thread).should be_nil
  end

  it "should allow the user to schedule jobs" do
    manager = EMManager.new
    manager.start
    manager.running?.should be_true
    block_ran = false
    manager.schedule {
      block_ran = true
    }
    sleep 0.5
    block_ran.should == true

    manager.halt
    manager.join
    manager.running?.should be_false
  end

  it "should allow the user to keep the reactor alive until forcibly stopped" do
    manager = EMManager.new
    manager.start
    manager.running?.should be_true
    manager.schedule { "foo" }

    manager.running?.should be_true

    # forcibly stop the reactor
    manager.halt
    manager.join
    manager.running?.should be_false
  end
  
  it "should allow the user to schedule at job after a specified interval" do
    manager = EMManager.new
    manager.start
    manager.running?.should be_true
    block_called = false
    manager.add_timer(1) { block_called = true }
    sleep 0.5
    block_called.should == false
    sleep 1
    block_called.should == true
    manager.halt
    manager.join
  end

  it "should allow the user to schedule at job repeatidly with a specified interval" do
    manager = EMManager.new
    manager.start
    manager.running?.should be_true
    times_block_called = 0
    manager.add_periodic_timer(1) { times_block_called += 1 }
    sleep 0.6
    times_block_called.should == 0
    sleep 0.6
    times_block_called.should == 1
    sleep 1.2
    times_block_called.should == 2

    manager.halt
    manager.join
  end
end
