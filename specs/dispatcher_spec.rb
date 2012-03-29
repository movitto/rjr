require 'rjr/dispatcher'

describe RJR::Request do
  it "invokes registered handler in request context" do
    invoked = false
    rjr_callback = Object.new
    request = RJR::Request.new :method => 'foobar',
                               :method_args => ['a', 123],
                               :headers     => {'qqq' => 'www'},
                               :rjr_callback => rjr_callback,
                               :rjr_node_id  => 'test',
                               :rjr_node_type => 'test_type',
                               :handler => lambda { |p1, p2|
                                 invoked = true
                                 @method.should == 'foobar'
                                 p1.should == 'a'
                                 p2.should == 123
                                 @headers['qqq'].should == 'www'
                                 @rjr_callback.should == rjr_callback
                                 @rjr_node_id.should == 'test'
                                 @rjr_node_type.should == 'test_type'
                               }
    request.handle
    invoked.should == true
  end
end

describe RJR::Result do
  it "should handle successful results" do
    result = RJR::Result.new :result => 'foobar'
    result.success.should == true
    result.failed.should  == false
    result.result.should  == 'foobar'
    result.error_code.should == nil
    result.error_msg.should == nil
    result.error_class.should == nil
  end

  it "should handle errors" do
    result = RJR::Result.new :error_code => 123, :error_msg => 'abc', :error_class => ArgumentError
    result.success.should == false
    result.failed.should  == true
    result.result.should  == nil
    result.error_code.should == 123
    result.error_msg.should == 'abc'
    result.error_class.should == ArgumentError
  end
end


describe RJR::Handler do
  it "should return method not found result if method name is not specified" do
    handler = RJR::Handler.new :method => nil
    result = handler.handle
    result.should == RJR::Result.method_not_found
  end

  it "should invoke registered handler for request" do
    invoked = false
    handler = RJR::Handler.new :method => 'foobar',
                               :handler => lambda {
                                 invoked = true
                               }
    handler.handle({:method_args => [] })
    invoked.should == true
  end

  it "should return handler's return value in successful result" do
    retval  = Object.new
    handler = RJR::Handler.new :method => 'foobar',
                               :handler => lambda {
                                 retval
                               }
    res = handler.handle({:method_args => [] })
    res.success.should == true
    res.result.should == retval
  end

  it "should catch handler errors and return error result" do
    handler = RJR::Handler.new :method => 'foobar',
                               :method_args => [],
                               :handler => lambda {
                                 raise ArgumentError, "uh oh!"
                               }
    res = handler.handle({:method_args => [] })
    res.failed.should == true
    res.error_code.should == -32000
    res.error_msg.should == "uh oh!"
    res.error_class.should == ArgumentError
  end
end

describe RJR::Dispatcher do
  it "should dispatch request to registered handler" do
    invoked_foobar = false
    invoked_barfoo = false
    RJR::Dispatcher.init_handlers
    RJR::Dispatcher.add_handler('foobar') { |param1, param2|
      invoked_foobar = true
      param1.should == "param1"
      param2.should == "param2"
      "retval"
    }
    RJR::Dispatcher.add_handler('barfoo') { |param1, param2|
      invoked_barfoo = true
    }
    res = RJR::Dispatcher.dispatch_request('foobar', :method_args => ['param1', 'param2'])
    res.success.should == true
    res.result.should == "retval"
    invoked_foobar.should == true
    invoked_barfoo.should == false
  end

  it "should return method not found result if handler for specified message is missing" do
    RJR::Dispatcher.init_handlers
    res = RJR::Dispatcher.dispatch_request('foobar')
    res.should == RJR::Result.method_not_found
  end

  it "should handle success response" do
    res = RJR::Result.new :result => 'woot'
    processed = RJR::Dispatcher.handle_response(res)
    processed.should == "woot"
  end

  it "should handle error response" do
    lambda{
      res = RJR::Result.new :error_code => 123, :error_msg => "bah", :error_class => ArgumentError
      RJR::Dispatcher.handle_response(res)
    }.should raise_error(Exception, "bah")
    #}.should raise_error(ArgumentError, "bah")
  end
end
