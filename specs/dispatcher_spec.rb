require 'rjr/dispatcher'

module RJR
  describe Dispatcher do
    context "registering handlers" do
      it "should load module"

      it "should register handler for method" do
        d = Dispatcher.new
        h = proc {}
        d.handle('foobar', h)
        d.handlers['foobar'].should == h
        d.handles?('foobar').should be_true
      end

      it "should set handler from block param" do
        d = Dispatcher.new
        h = proc {}
        d.handle('foobar', &h)
        d.handlers['foobar'].should == h
        d.handles?('foobar').should be_true
      end

      it "should register handler for multiple methods" do
        d = Dispatcher.new
        h = proc {}
        d.handle(['foobar', 'barfoo'], &h)
        d.handlers['foobar'].should == h
        d.handlers['barfoo'].should == h
        d.handles?('foobar').should be_true
        d.handles?('barfoo').should be_true
      end
    end

    context "dispatching requests" do
      context "handler does not exist" do
        it "should return method not found" do
          d = Dispatcher.new
          r = d.dispatch :rjr_method => 'foobar'
          r.should == Result.method_not_found('foobar')
        end
      end

      context "handler is registered" do
        it "should invoke handler" do
          invoked = false
          d = Dispatcher.new
          h = proc { invoked = true }
          d.handle('foobar', &h)

          d.dispatch :rjr_method => 'foobar'
          invoked.should be_true
        end

        context "handler is regex" do
          it "should match method"
        end

        it "should pass params to handler" do
          param = nil
          d = Dispatcher.new
          h = proc { |p| param = p}
          d.handle('foobar', &h)

          d.dispatch(:rjr_method => 'foobar', :rjr_method_args => [42])
          param.should == 42
        end

        it "should return request result" do
          d = Dispatcher.new
          h = proc { 42 }
          d.handle('foobar', &h)

          r = d.dispatch :rjr_method => 'foobar'
          r.result.should == 42
        end

        it "should return request error" do
          d = Dispatcher.new
          h = proc { raise ArgumentError, "bah" }
          d.handle('foobar', &h)

          r = d.dispatch :rjr_method => 'foobar'
          r.error_code.should == -32000
          r.error_msg.should == "bah"
          r.error_class.should == ArgumentError
        end

        context "keep_requests is false (default)" do
          it "should not store requests" do
            d = Dispatcher.new
            d.handle('foobar') {}
            d.requests.should be_empty
            d.dispatch :rjr_method => 'foobar'
            d.requests.should be_empty
          end
        end

        context "keep_requests is true" do
          it "should store request locally" do
            d = Dispatcher.new :keep_requests => true
            h = proc {}
            d.handle('foobar', &h)

            d.requests.size.should == 0
            d.dispatch :rjr_method => 'foobar'
            d.requests.size.should == 1
            d.requests.first.rjr_method.should == 'foobar'
          end

          it "should set params on request" do
            d = Dispatcher.new
            d.keep_requests = true
            h = proc { |p| }
            d.handle('foobar', &h)

            d.dispatch(:rjr_method => 'foobar', :rjr_method_args => [42])
            d.requests.first.rjr_method_args.should == [42]
          end

          it "should set result on request" do
            d = Dispatcher.new
            d.keep_requests = true
            h = proc { 42 }
            d.handle('foobar', &h)

            d.dispatch :rjr_method => 'foobar'
            d.requests.first.result.result.should == 42
          end
        end
      end
    end

    context "processing responses" do
      context "successful response" do
        it "should return result" do
          r = Result.new :result => 'woot'
          d = Dispatcher.new
          p = d.handle_response(r)
          p.should == "woot"
        end
      end

      context "failed response" do
        it "should raise error" do
          r = Result.new :error_code => 123, :error_msg => "bah",
                         :error_class => ArgumentError
          d = Dispatcher.new
          lambda{
            d.handle_response(r)
          }.should raise_error(Exception, "bah")
          #}.should raise_error(ArgumentError, "bah")
        end
      end
    end

  end # describe Dispatcher
end # module RJR
