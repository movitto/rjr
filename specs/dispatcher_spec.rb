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
  before(:each) do
    RJR::DispatcherStat.reset
  end

  it "should return method not found result if method name is not specified" do
    handler = RJR::Handler.new :method => nil
    result = handler.handle
    result.should == RJR::Result.method_not_found(nil)
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

  it "should create dispatcher stat when invoking handler" do
    handler = RJR::Handler.new :method => 'foobar',
                               :handler => lambda { 42 }
    handler.handle({:method_args => [] })
    RJR::DispatcherStat.stats.size.should == 1
    RJR::DispatcherStat.stats.first.request.method.should == 'foobar'
    RJR::DispatcherStat.stats.first.result.result.should == 42
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

describe RJR::DispatcherStat do
  before(:each) do
    RJR::DispatcherStat.reset
  end

  it "should store request and result" do
    req = RJR::Request.new
    res = RJR::Result.new
    stat = RJR::DispatcherStat.new req, res
    (stat.request == req).should be_true
    stat.result.should == res
  end

  it "should track global stats" do
    req = RJR::Request.new
    res = RJR::Result.new
    stat = RJR::DispatcherStat.new req, res

    RJR::DispatcherStat << stat
    RJR::DispatcherStat.stats.should include(stat)
  end

  it "should be convertable to json" do
    req = RJR::Request.new :method => 'foobar', :method_args => [:a, :b],
                           :headers => { :foo => :bar }, :rjr_node_type => :local,
                           :rjr_node_id => :loc1
    res = RJR::Result.new :result => 42

    stat = RJR::DispatcherStat.new req, res
    j = stat.to_json()
    j.should include('"json_class":"RJR::DispatcherStat"')
    j.should include('"method":"foobar"')
    j.should include('"method_args":["a","b"]')
    j.should include('"headers":{"foo":"bar"}')
    j.should include('"rjr_node_type":"local"')
    j.should include('"rjr_node_id":"loc1"')
    j.should include('"result":42')
  end

  it "should be convertable from json" do
    j = '{"json_class":"RJR::DispatcherStat","data":{"request":{"method":"foobar","method_args":["a","b"],"headers":{"foo":"bar"},"rjr_node_type":"local","rjr_node_id":"loc1"},"result":{"result":42,"error_code":null,"error_msg":null,"error_class":null}}}'
    s = JSON.parse(j)

    s.class.should == RJR::DispatcherStat
    s.request.method.should == 'foobar'
    s.request.method_args.should == ['a', 'b']
    s.request.headers.should == { 'foo' => 'bar' }
    s.request.rjr_node_type.should == 'local'
    s.request.rjr_node_id.should == 'loc1'
    s.result.result.should == 42
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

  it "should allow user to determine registered handlers" do
    foobar = lambda {}
    barfoo = lambda {}
    RJR::Dispatcher.add_handler('foobar', &foobar)
    RJR::Dispatcher.add_handler('barfoo', &barfoo)

    RJR::Dispatcher.has_handler_for?('foobar').should be_true
    RJR::Dispatcher.has_handler_for?('barfoo').should be_true
    RJR::Dispatcher.has_handler_for?('money').should be_false

    RJR::Dispatcher.handler_for('foobar').handler_proc.should == foobar
    RJR::Dispatcher.handler_for('barfoo').handler_proc.should == barfoo
    RJR::Dispatcher.handler_for('money').should be_nil
  end

  it "should allow a single handler to be subscribed to multiple methods" do
    invoked_handler = 0
    RJR::Dispatcher.init_handlers
    RJR::Dispatcher.add_handler(['foobar', 'barfoo']) { |param1, param2|
      invoked_handler += 1
    }
    RJR::Dispatcher.dispatch_request('foobar', :method_args => ['param1', 'param2'])
    RJR::Dispatcher.dispatch_request('barfoo', :method_args => ['param1', 'param2'])
    invoked_handler.should == 2
  end

  it "should return method not found result if handler for specified message is missing" do
    RJR::Dispatcher.init_handlers
    res = RJR::Dispatcher.dispatch_request('foobar')
    res.should == RJR::Result.method_not_found('foobar')
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
