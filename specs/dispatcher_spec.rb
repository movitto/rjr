require 'rjr/dispatcher'

module RJR
  describe Dispatcher do
    describe "#requests" do
      it "returns dispatcher requests" do
        d = Dispatcher.new
        d.instance_variable_set(:@requests, ['requests'])
        d.requests.should == ['requests']
      end
    end

    describe "#store_request" do
      context "keep_requests is true" do
        it "stores request locally" do
          d = Dispatcher.new :keep_requests => true
          d.store_request 'request'
          d.requests.should == ['request']
        end
      end

      context "keep_requests is false" do
        it "does not store request locally" do
          d = Dispatcher.new :keep_requests => false
          d.store_request 'request'
          d.requests.should == []
        end
      end
    end

    it "does not keep requests by default" do
      d = Dispatcher.new
      d.store_request 'request'
      d.requests.should == []
    end

    it "initializes handlers" do
      Dispatcher.new.handlers.should == {}
    end

    it "initializes environments" do
      Dispatcher.new.environments.should == {}
    end

    it "initializes requests" do
      Dispatcher.new.requests.should == []
    end

    describe "#clear!" do
      it "clears handlers" do
        d = Dispatcher.new
        d.handlers['foo'] = 'handler'
        d.clear!
        d.handlers.should == {}
      end

      it "clears environments" do
        d = Dispatcher.new
        d.environments['foo'] = 'envi'
        d.clear!
        d.environments.should == {}
      end

      it "clears requests" do
        d = Dispatcher.new :keep_requests => true
        d.store_request 'foo'
        d.clear!
        d.requests.should == []
      end
    end

    describe "#add_module" do
      it 'requires module' do
        d = Dispatcher.new
        d.should_receive(:require).with('module')
        d.should_receive(:dispatch_module) # stub out
        d.add_module('module')
      end

      it 'invokes dispatch_module method' do
        d = Dispatcher.new
        d.should_receive(:require) # stub out
        d.should_receive(:dispatch_module).with(d)
        d.add_module('module')
      end

      it "returns self" do
        d = Dispatcher.new
        d.should_receive(:require) # stub out
        d.should_receive(:dispatch_module) # stub out
        d.add_module('module').should == d
      end
    end

    describe "#handle" do
      it "registers callback for specifed signature" do
        d = Dispatcher.new
        cb = proc {}
        d.handle 'foobar', cb
        d.handlers['foobar'].should == cb
      end

      it "registers block for specifed signature" do
        d = Dispatcher.new
        cb = proc {}
        d.handle 'foobar', &cb
        d.handlers['foobar'].should == cb
      end

      it "registers callback for specifed signatures" do
        d = Dispatcher.new
        cb = proc {}
        d.handle ['foobar', 'barfoo'], cb
        d.handlers['foobar'].should == cb
        d.handlers['barfoo'].should == cb
      end

      it "registers block for specifed signatures" do
        d = Dispatcher.new
        cb = proc {}
        d.handle ['foobar', 'barfoo'], &cb
        d.handlers['foobar'].should == cb
        d.handlers['barfoo'].should == cb
      end
    end

    describe "#handler_for" do
      context "dispatcher has handler" do
        it "returns registered handler" do
          d = Dispatcher.new
          cb = proc {}
          d.handle 'foobar', cb
          d.handler_for('foobar').should == cb
        end
      end

      context "dispatcher does not have handler" do
        it "returns nil" do
          d = Dispatcher.new
          d.handler_for('foobar').should be_nil
        end
      end

      it "matches regex signature" do
        d = Dispatcher.new
        cb = proc {}
        d.handle /foobar.*/, cb
        d.handler_for('foobar1').should == cb
        d.handler_for('barfoo1').should be_nil
      end

      context "mulitple matches" do
        it "returns exact match before regex" do
          d = Dispatcher.new
          cb1 = proc{ 1 }
          cb2 = proc{ 2 }
          d.handle /foobar.*/, cb1
          d.handle "foobar1",  cb2
          d.handler_for("foobar1").should == cb2
        end
      end
    end

    describe "#handles?" do
      context "dispatcher has handler" do
        it "returns true" do
          d = Dispatcher.new
          cb = proc {}
          d.handle 'foobar', cb
          d.handles?('foobar').should be_truthy
        end
      end

      context "dispatcher does not have handler" do
        it "returns false" do
          d = Dispatcher.new
          d.handles?('foobar').should be_falsey
        end
      end
    end

    describe "#env" do
      it "registers environment for specified signature" do
        d = Dispatcher.new
        d.env('foobar', 'fooenv')
        d.environments['foobar'].should == 'fooenv'
      end

      it "registers environment for specified signatures" do
        d = Dispatcher.new
        d.env(['foobar', 'barfoo'], 'fooenv')
        d.environments['foobar'].should == 'fooenv'
        d.environments['barfoo'].should == 'fooenv'
      end
    end

    describe "#env_for" do
      context "dispatcher has environment" do
        it "returns registered environment" do
          d = Dispatcher.new
          d.env('foobar', 'fooenv')
          d.env_for('foobar').should == 'fooenv'
        end
      end

      context "dispatcher does not have environment" do
        it "returns nil" do
          d = Dispatcher.new
          d.env_for('foobar').should be_nil
        end
      end

      it "matches regex signature" do
        d = Dispatcher.new
        d.env(/foobar.*/, 'fooenv')
        d.env_for('foobar1').should == 'fooenv'
        d.env_for('barfoo1').should be_nil
      end

      context "mulitple matches" do
        it "returns exact match before regex" do
          d = Dispatcher.new
          d.env /foobar.*/, 'foo'
          d.env "foobar1",  'bar'
          d.env_for("foobar1").should == 'bar'
        end
      end
    end

    describe "#dispatch" do
      context "no handler registered for method" do
        it "returns Result.method_not_found" do
          expected = Result.method_not_found('foobar')
          Dispatcher.new.dispatch(:rjr_method => 'foobar').should == expected
        end
      end

      it "creates request with registered handler" do
        handler = proc {}
        d = Dispatcher.new
        d.handle 'foobar', &handler

        expected = {:rjr_method => 'foobar', :rjr_handler => handler}
        Request.should_receive(:new).with(expected).and_call_original
        d.dispatch :rjr_method => 'foobar'
      end

      it "sets request environment" do
        d = Dispatcher.new
        d.env 'foobar', 'fooenv'
        d.handle 'foobar', proc {}

        r = Request.new
        Request.should_receive(:new).and_return(r)
        r.should_receive(:set_env).with('fooenv')
        d.dispatch :rjr_method => 'foobar'
      end

      it "handles request" do
        d = Dispatcher.new
        d.handle 'foobar', proc {}

        r = Request.new
        Request.should_receive(:new).and_return(r)
        r.should_receive(:handle).and_call_original
        d.dispatch :rjr_method => 'foobar'
      end

      it "returns request result" do
        d = Dispatcher.new
        d.handle 'foobar', proc {}

        r = Request.new
        Request.should_receive(:new).and_return(r)

        result = Result.new :result => 0
        r.should_receive(:handle).and_return(0)
        d.dispatch(:rjr_method => 'foobar').should == result
      end

      context "successful request" do
        it "returns return value in result" do
          d = Dispatcher.new
          d.handle 'foobar', proc { 42 }
          d.dispatch(:rjr_method => 'foobar').result.should == 42
        end
      end

      context "exception during request" do
        it "returns exception error in result" do
          d = Dispatcher.new
          d.handle 'foobar', proc { raise ArgumentError, "invalid" }

          result = Result.new :error_code  => -32000,
                              :error_msg   => "invalid",
                              :error_class => ArgumentError
          d.dispatch(:rjr_method => 'foobar').should == result
        end
      end

      it "stores request" do
        d = Dispatcher.new :keep_requests => true
        d.handle 'foobar', proc { 42 }
        d.should_receive(:store_request).and_call_original
        d.dispatch(:rjr_method => 'foobar')
        d.requests.size.should == 1

        d.requests.first.rjr_method.should == 'foobar'
        d.requests.first.result.result.should == 42
      end
    end

    describe "#handle_response" do
      context "error response" do
        it "raises exception with response error" do
          r = Result.new :error_code => -32000, :error_msg => "invalid"
          d = Dispatcher.new
          lambda{
            d.handle_response(r)
          }.should raise_error(Exception, "invalid")
        end
      end

      context "successful response" do
        it "returns result" do
          r = Result.new :success => true, :result => 42
          d = Dispatcher.new
          d.handle_response(r).should == 42
        end
      end
    end

    describe "Behaviour" do
      context "registering handlers" do
        it "should register handler for method" do
          d = Dispatcher.new
          h = proc {}
          d.handle('foobar', h)
          d.handlers['foobar'].should == h
          d.handles?('foobar').should be_truthy
        end

        it "should set handler from block param" do
          d = Dispatcher.new
          h = proc {}
          d.handle('foobar', &h)
          d.handlers['foobar'].should == h
          d.handles?('foobar').should be_truthy
        end

        it "should register handler for multiple methods" do
          d = Dispatcher.new
          h = proc {}
          d.handle(['foobar', 'barfoo'], &h)
          d.handlers['foobar'].should == h
          d.handlers['barfoo'].should == h
          d.handles?('foobar').should be_truthy
          d.handles?('barfoo').should be_truthy
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
            invoked.should be_truthy
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
    end # describe Behaviour
  end # describe Dispatcher
end # module RJR
