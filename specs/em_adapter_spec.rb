require 'thread'
require 'rjr/em_adapter'

module RJR
  describe EMAdapter do
    after(:each) do
      EMAdapter.instance.halt
      EMAdapter.instance.join
    end

    it "should be a singleton" do
      em = EMAdapter.instance
      EMAdapter.instance.should == em
    end

    it "should start the reactor" do
      em = EMAdapter.instance
      em.start
      em.reactor_running?.should be_true
      ['sleep', 'run'].should include(em.reactor_thread.status)
    end

    it "should only start the reactor once" do
      em = EMAdapter.instance
      em.start

      ot = em.reactor_thread
      em.start
      em.reactor_thread.should == ot
    end

    it "should halt the reactor" do
      em = EMAdapter.instance
      em.start

      em.halt
      em.join
      em.reactor_running?.should be_false
      em.reactor_thread.should be_nil
    end

    it "should dispatch all requests to eventmachine" do
      em = EMAdapter.instance
      em.start

      invoked = false
      m,c = Mutex.new, ConditionVariable.new
      em.schedule {
        invoked = true
        m.synchronize { c.signal }
      }
      m.synchronize { c.wait m, 0.5 } if !invoked
      invoked.should be_true
    end

  end
end
