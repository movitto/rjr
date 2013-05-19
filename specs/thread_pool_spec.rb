require 'thread'
require 'rjr/thread_pool'

# TODO ? test ThreadPoolJob being_executed?, completed?, exec, handle_timeout!

module RJR
  describe ThreadPool do
    after(:each) do
      ThreadPool.instance.stop
      ThreadPool.instance.join
    end

    it "should be a singleton" do
      tp = ThreadPool.instance
      ThreadPool.instance.should == tp
    end

    it "should start the thread pool" do
      tp = ThreadPool.instance
      tp.start
      tp.instance_variable_get(:@worker_threads).size.should == ThreadPool.num_threads
      tp.should be_running
    end

    it "should stop the thread pool" do
      tp = ThreadPool.instance
      tp.start
      tp.stop
      tp.join
      tp.instance_variable_get(:@worker_threads).size.should == 0
      tp.should_not be_running
    end

    it "should run work" do
      tp = ThreadPool.instance
      tp.start

      jobs_executed = []
      m,c = Mutex.new, ConditionVariable.new
      tp << ThreadPoolJob.new { jobs_executed << 1 ; m.synchronize { c.signal } }
      tp << ThreadPoolJob.new { jobs_executed << 2 ; m.synchronize { c.signal }  }

      m.synchronize { c.wait m, 0.1 } unless jobs_executed.include?(1)
      m.synchronize { c.wait m, 0.1 } unless jobs_executed.include?(2)
      jobs_executed.should include(1)
      jobs_executed.should include(2)
    end

  end
end
