require 'rjr/dispatcher'
require 'rjr/thread_pool2'

# TODO ? test ThreadPoolJob being_executed?, completed?, exec, handle_timeout!

describe ThreadPool2 do
  it "should start and stop successfully" do
    tp = ThreadPool2.new 10, :timeout => 10
    tp.running?.should be_false

    tp.start
    tp.running?.should be_true
    tp.instance_variable_get(:@worker_threads).size.should == 10
    tp.instance_variable_get(:@manager_thread).should_not be_nil
    ['run', 'sleep'].should include(tp.instance_variable_get(:@manager_thread).status)
    sleep 0.5

    tp.stop
    tp.running?.should be_false
    tp.instance_variable_get(:@manager_thread).should be_nil
    tp.instance_variable_get(:@worker_threads).size.should == 0
  end

  it "should accept and run work" do
    tp = ThreadPool2.new 10, :timeout => 10
    tp.start

    tp.instance_variable_get(:@work_queue).size.should == 0
    jobs_executed = []
    tp << ThreadPool2Job.new { jobs_executed << 1 }
    tp << ThreadPool2Job.new { jobs_executed << 2 }
    tp.instance_variable_get(:@work_queue).size.should == 2

    sleep 0.5
    jobs_executed.should include(1)
    jobs_executed.should include(2)
    tp.instance_variable_get(:@work_queue).size.should == 0

    tp.stop
  end
end
