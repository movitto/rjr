require 'thread'
require 'rjr/em_adapter'

module RJR
  describe EMAdapter do
    before(:each) do
      @em = EMAdapter.new
    end

    after(:each) do
      @em.halt.join
    end

    it "should start the reactor" do
      @em.start
      @em.reactor_running?.should be_true
      ['sleep', 'run'].should include(@em.reactor_thread.status)
    end

    it "should only start the reactor once" do
      @em.start

      ot = @em.reactor_thread
      @em.start
      @em.reactor_thread.should == ot
    end

    it "should halt the reactor" do
      @em.start

      @em.halt
      @em.join
      @em.reactor_running?.should be_false
      @em.reactor_thread.should be_nil
    end

    it "should dispatch all requests to eventmachine" do
      @em.start

      invoked = false
      m,c = Mutex.new, ConditionVariable.new
      @em.schedule {
        invoked = true
        m.synchronize { c.signal }
      }
      if !invoked
        if RUBY_VERSION < "1.9"
          # XXX ruby 1.8 didn't support timeout via cv.wait
          Thread.new { sleep 0.5 ; c.signal }
          m.synchronize { c.wait m }
        else
          m.synchronize { c.wait m, 0.5 }
        end
      end
      invoked.should be_true
    end

  end
end
