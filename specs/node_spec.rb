require 'rjr/node'

describe RJR::Node do
  it "should initialize properly from params" do
    node = RJR::Node.new :node_id => 'foobar',
                         :headers => {:h => 123}
    node.node_id.should == 'foobar'
    node.message_headers[:h].should == 123
  end

  it "should start eventmachine and allow multiple blocks to be invoked in its context" do
    block1_called = false
    block2_called = false

    node = RJR::Node.new :node_id => 'foobar',
                         :headers => {:h => 123}
    node.em_run {
      ThreadPoolManager.running?.should be_true
      EMAdapter.running?.should be_true
      block1_called = true
      node.em_run {
        EMAdapter.running?.should be_true
        block2_called = true
        node.halt
      }
    }
    node.join

    block1_called.should be_true
    block2_called.should be_true
  end

  #it "should gracefully stop managed subsystems" do
  #  # TODO test w/ keep_alive
  #  node = RJR::Node.new :node_id => 'foobar',
  #                       :headers => {:h => 123}
  #  node.em_run {}
  #  EMAdapter.running?.should be_true
  #  ThreadPoolManager.running?.should be_true
  #  node.stop
  #  node.join
  #end

  it "should halt managed subsystems" do
    node = RJR::Node.new :node_id => 'foobar',
                         :headers => {:h => 123}
    node.em_run {}
    EMAdapter.running?.should be_true
    ThreadPoolManager.running?.should be_true
    node.halt
    node.join
    EMAdapter.running?.should be_false
    ThreadPoolManager.running?.should be_false
  end

  it "should run a block directly via eventmachine" do
    block1_called = false
    block1_thread = nil

    node = RJR::Node.new :node_id => 'foobar',
                         :headers => {:h => 123}
    node.em_run {
      block1_called = true
      block1_thread = Thread.current
      node.halt
    }
    reactor_thread = EMAdapter.instance_variable_get(:@em_manager).instance_variable_get(:@reactor_thread)
    node.join
    block1_called.should be_true
    block1_thread.should == reactor_thread
  end

  it "should run a block in a thread via eventmachine" do
    block1_called = false
    block1_thread = nil

    node = RJR::Node.new :node_id => 'foobar',
                         :headers => {:h => 123}
    node.em_run_async {
      block1_called = true
      block1_thread = Thread.current
      node.halt
    }
    reactor_thread = EMAdapter.instance_variable_get(:@em_manager).instance_variable_get(:@reactor_thread)
    worker_threads = ThreadPoolManager.thread_pool.instance_variable_get(:@worker_threads)
    node.join
    block1_called.should be_true
    block1_thread.should_not == reactor_thread   
    worker_threads.should include(block1_thread)
  end

  it "should schedule a job to be run in a thread via eventmachine after a specified interval" do
    block1_called = false
    block1_thread = nil

    node = RJR::Node.new :node_id => 'foobar',
                         :headers => {:h => 123}
    node.em_schedule_async(1) {
      block1_called = true
      block1_thread = Thread.current
      node.halt
    }
    reactor_thread = EMAdapter.instance_variable_get(:@em_manager).instance_variable_get(:@reactor_thread)
    worker_threads = ThreadPoolManager.thread_pool.instance_variable_get(:@worker_threads)

    sleep 0.5
    block1_called.should be_false

    node.join
    block1_called.should be_true
    block1_thread.should_not == reactor_thread   
    worker_threads.should include(block1_thread)
  end

  it "should schedule a job to be run directly via eventmachine repeatidly with specified interval" do
    block1_threads = []

    node = RJR::Node.new :node_id => 'foobar',
                         :headers => {:h => 123}
    node.em_repeat(1) {
      block1_threads << Thread.current
    }
    reactor_thread = EMAdapter.instance_variable_get(:@em_manager).instance_variable_get(:@reactor_thread)

    sleep 0.5
    block1_threads.size.should == 0

    sleep 0.6
    block1_threads.size.should == 1

    sleep 1.1
    block1_threads.size.should == 2
    node.halt
    node.join

    block1_threads.each { |bt|
      bt.should == reactor_thread   
    }
  end

  it "should schedule a job to be run in a thread via eventmachine repeatidly with specified interval" do
    block1_threads = []

    node = RJR::Node.new :node_id => 'foobar',
                         :headers => {:h => 123}
    node.em_repeat_async(1) {
      block1_threads << Thread.current
    }
    reactor_thread = EMAdapter.instance_variable_get(:@em_manager).instance_variable_get(:@reactor_thread)
    worker_threads = ThreadPoolManager.thread_pool.instance_variable_get(:@worker_threads)

    sleep 0.5
    block1_threads.size.should == 0

    sleep 0.6
    block1_threads.size.should == 1

    sleep 1.1
    block1_threads.size.should == 2
    node.halt
    node.join

    block1_threads.each { |bt|
      bt.should_not == reactor_thread   
      worker_threads.should include(bt)
    }
  end

end
