require 'rjr/request'

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
  end # describe Request
end # module RJR
