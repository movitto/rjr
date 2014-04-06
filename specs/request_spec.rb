require 'rjr/request'

module RJR
  describe Request do
    describe "#initialize" do
      it "sets rjr method" do
        request = Request.new :rjr_method => 'foobar'
        request.rjr_method.should == 'foobar'
      end

      it "sets rjr method args" do
        args = ['a', 'r', 'g']
        request = Request.new :rjr_method_args => args
        request.rjr_method_args.should == args
      end

      it "sets rjr headers" do
        headers = {:h => :s}
        request = Request.new :rjr_headers => headers
        request.rjr_headers.should == headers
      end

      it "sets client ip" do
        request = Request.new :rjr_client_ip => '127.0.0.1'
        request.rjr_client_ip.should == '127.0.0.1'
      end

      it "sets client port" do
        request = Request.new :rjr_client_port => 1234
        request.rjr_client_port.should == 1234
      end

      it "sets callback" do
        request = Request.new :rjr_callback => :cb
        request.rjr_callback.should == :cb
      end

      it "sets node" do
        request = Request.new :rjr_node => :node
        request.rjr_node.should == :node
      end

      it "sets node id" do
        request = Request.new :rjr_node_id => :node_id
        request.rjr_node_id.should == :node_id
      end

      it "node type" do
        request = Request.new :rjr_node_type => :node_type
        request.rjr_node_type.should == :node_type
      end

      it "rjr handler" do
        request = Request.new :rjr_handler => :handler
        request.rjr_handler.should == :handler
      end

      it "initialies new RJR::Arguments object from argument list" do
        args = ['a', 'r', 'g']
        request = Request.new :rjr_method_args => args
        request.rjr_method_args.should == args
        request.rjr_args.should be_an_instance_of(Arguments)
        request.rjr_args.args.should == args
      end

      it "sets default env to nil" do
        Request.new.rjr_env.should be_nil
      end

      it "sets default result to nil" do
        Request.new.result.should be_nil
      end
    end

    describe "#set_env" do
      it "extends request w/ specified module" do
        request = Request.new
        request.should_receive(:extend).with('foobar')
        request.set_env('foobar')
      end

      it "sets rjr_env" do
        request = Request.new
        request.should_receive(:extend)
        request.set_env('foobar')
        request.rjr_env.should == 'foobar'
      end
    end

    describe "#handle" do
      it "invokes the registered handler with args" do
        received = nil
        handler = proc { |arg| received = arg }
        request = Request.new :rjr_handler => handler,
                              :rjr_method_args => ['foo']
        request.handle
        received.should == 'foo'
      end

      it "invokes registered handler in request contenxt" do
        received = nil
        handler = proc { |arg| received = @var }

        request = Request.new :rjr_handler => handler
        request.instance_variable_set(:@var, 'foo')
        request.handle
        received.should == 'foo'
      end

      it "returns the handler return value" do
        handler = proc { |arg| 42 }
        request = Request.new :rjr_handler => handler
        request.handle.should == 42
      end
    end

    describe "#to_json" do
      it "returns the request in json format" do
        request = Request.new :rjr_method => 'foobar',
                              :rjr_method_args => [:a, :b],
                              :rjr_headers => { :header1 => :val1 },
                              :rjr_node_type => :local,
                              :rjr_node_id => :loc1
        j = request.to_json
        j.should include('"json_class":"RJR::Request"')
        j.should include('"rjr_method":"foobar"')
        j.should include('"rjr_method_args":["a","b"]')
        j.should include('"rjr_headers":{"header1":"val1"}')
        j.should include('"rjr_node_type":"local"')
        j.should include('"rjr_node_id":"loc1"')
      end

      it "includes the result in the json" do
        request = Request.new
        result = RJR::Result.new :result => 42,
                                 :error_code => 123,
                                 :error_msg  => 'error occurred',
                                 :error_class => 'ArgumentError'
        request.result = result

        j = request.to_json
        j.should include('"result":42')
        j.should include('"error_code":123')
        j.should include('"error_msg":"error occurred"')
        j.should include('"error_class":"ArgumentError"')
      end
    end

    describe "#json_create" do
      it "returns a new request from json" do
        j = '{"json_class":"RJR::Request","data":{"request":{"rjr_method":"foobar","rjr_method_args":["a","b"],"rjr_headers":{"foo":"bar"},"rjr_node_type":"local","rjr_node_id":"loc1"},"result":{"result":42,"error_code":null,"error_msg":null,"error_class":null}}}'
        request = JSON.parse(j, :create_additions => true)

        request.should be_an_instance_of(RJR::Request)
        request.rjr_method.should == 'foobar'
        request.rjr_method_args.should == ['a', 'b']
        request.rjr_headers.should == { 'foo' => 'bar' }
        request.rjr_node_type.should == 'local'
        request.rjr_node_id.should == 'loc1'

        request.result.should be_an_instance_of(RJR::Result)
        request.result.result.should == 42
      end
    end
  end # describe Request
end # module RJR
