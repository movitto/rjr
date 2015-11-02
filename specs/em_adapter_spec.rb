require 'thread'
require 'rjr/util/em_adapter'

module RJR
  describe EMAdapter do
    before(:each) do
      @em = EMAdapter.new
    end

    after(:each) do
      @em.halt.join
    end

    describe "#start" do
      it "should start the reactor" do
        @em.start
        @em.reactor_running?.should be_truthy
        ['sleep', 'run'].should include(@em.reactor_thread.status)
      end

      it "should only start the reactor once" do
        @em.start

        ot = @em.reactor_thread
        @em.start
        @em.reactor_thread.should == ot
      end
    end

    describe "#stop" do
      it "should halt the reactor" do
        @em.start

        @em.halt
        @em.join
        @em.reactor_running?.should be_falsey
        @em.reactor_thread.should be_nil
      end
    end

    describe "#join" do
      it "joins reactor thread" do
        th = Object.new
        th.should_receive(:join).twice # XXX also called in after block above
        @em.instance_variable_set(:@reactor_thread, th)
        @em.join
      end
    end

    it "should forward all messages to eventmachine" do
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
      invoked.should be_truthy
    end

  end
end
