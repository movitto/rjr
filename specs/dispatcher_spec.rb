require 'rjr/dispatcher'

module RJR
  describe Result do
    describe "#initialize" do
      it "initializes default attributes" do
        result = Result.new
        result.result.should be_nil
        result.error_code.should be_nil
        result.error_msg.should be_nil
        result.error_class.should be_nil
      end

      it "stores result" do
        result = Result.new :result => 'foobar'
        result.result.should == 'foobar'
      end

      it "stores error" do
        result = Result.new :error_code => 123, :error_msg => 'abc',
                            :error_class => ArgumentError
        result.error_code.should == 123
        result.error_msg.should == 'abc'
        result.error_class.should == ArgumentError
      end

      context "when an error code is not specified" do
        it "should be marked as successful" do
          result = Result.new
          result.success.should == true
          result.failed.should  == false
        end
      end

      context "when an error code is specified" do
        it "should be marked as failed" do
          result = Result.new :error_code => 123
          result.success.should == false
          result.failed.should  == true
        end
      end

    end # describe #initialize

    describe "#==" do
      it "return true for equal results"
      it "return false for inequal results"
    end # descirbe #==

  end # describe Result
end # module RJR

module RJR
  describe Request do
    it "should be convertable to json" do
      req = Request.new :rjr_method => 'foobar',
                        :rjr_method_args => [:a, :b],
                        :rjr_headers => { :header1 => :val1 },
                        :rjr_node_type => :local,
                        :rjr_node_id => :loc1

      res = RJR::Result.new :result => 42,
                            :error_code => 123,
                            :error_msg  => 'error occurred',
                            :error_class => 'ArgumentError'
      req.result = res

      j = req.to_json()
      j.should include('"json_class":"RJR::Request"')
      j.should include('"rjr_method":"foobar"')
      j.should include('"rjr_method_args":["a","b"]')
      j.should include('"rjr_headers":{"header1":"val1"}')
      j.should include('"rjr_node_type":"local"')
      j.should include('"rjr_node_id":"loc1"')
      j.should include('"result":42')
      j.should include('"error_code":123')
      j.should include('"error_msg":"error occurred"')
      j.should include('"error_class":"ArgumentError"')
    end

    it "should be convertable from json" do
      j = '{"json_class":"RJR::Request","data":{"request":{"rjr_method":"foobar","rjr_method_args":["a","b"],"rjr_headers":{"foo":"bar"},"rjr_node_type":"local","rjr_node_id":"loc1"},"result":{"result":42,"error_code":null,"error_msg":null,"error_class":null}}}'
      r = JSON.parse(j, :create_additions => true)

      r.class.should == RJR::Request
      r.rjr_method.should == 'foobar'
      r.rjr_method_args.should == ['a', 'b']
      r.rjr_headers.should == { 'foo' => 'bar' }
      r.rjr_node_type.should == 'local'
      r.rjr_node_id.should == 'loc1'
      r.result.result.should == 42
    end

    context "handling" do
      it "should invoke handler in request context" do
        method = 'foobar'
        params = ['a', 1]
        ni = 'test'
        nt = 'test_type'
        cb = Object.new
        headers = {'header1' => 'val1'}

        invoked = ip1 = ip2 = 
        icb = im = ini = int = ih = nil
        handler = proc { |p1, p2|
          invoked = true
          ip1     = p1
          ip2     = p2
          im      = @rjr_method
          ini     = @rjr_node_id
          int     = @rjr_node_type
          icb     = @rjr_callback
          ih      = @rjr_headers
        }

        request = Request.new :rjr_method      => method,
                              :rjr_method_args => params,
                              :rjr_headers     => headers,
                              :rjr_callback    => cb,
                              :rjr_node_id     => ni,
                              :rjr_node_type   => nt,
                              :rjr_handler     => handler

        request.handle
        invoked.should be_true
        ip1.should  == params[0]
        ip2.should  == params[1]
        im.should   == method
        ini.should  == ni
        int.should  == nt
        icb.should  == cb
        ih.should   == headers
      end
    end
  end
end

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

        it "should register request" do
          d = Dispatcher.new
          h = proc {}
          d.handle('foobar', &h)

          d.requests.size.should == 0
          d.dispatch :rjr_method => 'foobar'
          d.requests.size.should == 1
          d.requests.first.rjr_method.should == 'foobar'
        end

        it "should set params on request" do
          d = Dispatcher.new
          h = proc { |p| }
          d.handle('foobar', &h)

          d.dispatch(:rjr_method => 'foobar', :rjr_method_args => [42])
          d.requests.first.rjr_method_args.should == [42]
        end

        it "should set result on request" do
          d = Dispatcher.new
          h = proc { 42 }
          d.handle('foobar', &h)

          d.dispatch :rjr_method => 'foobar'
          d.requests.first.result.result.should == 42
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
