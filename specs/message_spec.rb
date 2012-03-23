require 'rjr/dispatcher'
require 'rjr/message'

describe RJR::RequestMessage do
  it "should accept request parameters" do
    msg = RJR::RequestMessage.new :method => 'test',
                                  :args   => ['a', 1],
                                  :headers => {:h => 2}
    msg.jr_method.should == "test"
    msg.jr_args.should =~ ['a', 1]
    msg.headers.should have_key(:h)
    msg.headers[:h].should == 2
    msg.msg_id.should =~ /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/
  end

  it "should produce valid json" do
    msg = RJR::RequestMessage.new :method => 'test',
                                  :args   => ['a', 1],
                                  :headers => {:h => 2}

    msg_string = msg.to_s
    msg_string.should include('"h":2')
    msg_string.should include('"method":"test"')
    msg_string.should include('"params":["a",1]')
    msg_string.should include('"jsonrpc":"2.0"')
    msg_string.should include('"id":"'+msg.msg_id+'"')
  end

  it "should parse request message string" do
    msg_uuid = RJR::RequestMessage.gen_uuid 
    msg_string = '{"jsonrpc": "2.0", ' +
                 '"id": "' + msg_uuid + '", ' +
                 '"method": "test", "params": ["a", 1]}'
    msg = RJR::RequestMessage.new :message => msg_string
    msg.json_message.should == msg_string
    msg.jr_method.should == 'test'
    msg.jr_args.should =~ ['a', 1]
    msg.msg_id.should == msg_uuid
  end

  it "should extract optional headers from message string" do
    msg_uuid = RJR::RequestMessage.gen_uuid 
    msg_string = '{"jsonrpc": "2.0", ' +
                 '"id": "' + msg_uuid + '", ' +
                 '"method": "test", "params": ["a", 1], ' +
                 '"h": 2}'
    msg = RJR::RequestMessage.new :message => msg_string, :headers => {'f' => 'g'}
    msg.json_message.should == msg_string
    msg.headers.should have_key 'h'
    msg.headers.should have_key 'f'
    msg.headers['h'].should == 2
    msg.headers['f'].should == 'g'
  end

  it "should fail if parsing invalid message string" do
    lambda {
      msg = RJR::RequestMessage.new :message => 'foobar'
    }.should raise_error JSON::ParserError
  end
end

describe RJR::ResponseMessage do
  it "should accept response parameters" do
    msg_id = RJR::RequestMessage.gen_uuid
    msg = RJR::ResponseMessage.new :id      => msg_id,
                                   :result  => RJR::Result.new(:result => 'success'),
                                   :headers => {:h => 2}
    msg.msg_id.should == msg_id
    msg.result.result == 'success'
    msg.headers.should have_key(:h)
    msg.headers[:h].should == 2
  end

  it "should produce valid result response json" do
    msg_id = RJR::RequestMessage.gen_uuid
    msg = RJR::ResponseMessage.new :id      => msg_id,
                                   :result  => RJR::Result.new(:result => 'success'),
                                   :headers => {:h => 2}
    msg_string = msg.to_s
    msg_string.should include('"id":"'+msg_id+'"')
    msg_string.should include('"result":"success"')
    msg_string.should include('"h":2')
    msg_string.should include('"jsonrpc":"2.0"')
  end

  it "should produce valid error response json" do
    msg_id = RJR::RequestMessage.gen_uuid
    msg = RJR::ResponseMessage.new :id      => msg_id,
                                   :result  => RJR::Result.new(:error_code => 404,
                                                               :error_msg => 'not found'),
                                   :headers => {:h => 2}
    msg_string = msg.to_s
    msg_string.should include('"id":"'+msg_id+'"')
    msg_string.should include('"h":2')
    msg_string.should include('"jsonrpc":"2.0"')
    msg_string.should include('"error":{')
    msg_string.should include('"code":404')
    msg_string.should include('"message":"not found"')
  end


  it "should parse result response message string" do
    msg_id = RJR::RequestMessage.gen_uuid
    msg_string = '{"id":"' + msg_id + '", ' +
                  '"result":"success","jsonrpc":"2.0"}'
    msg = RJR::ResponseMessage.new :message => msg_string
    msg.json_message.should == msg_string
    msg.msg_id.should == msg_id
    msg.result.success.should == true
    msg.result.failed.should == false
    msg.result.result.should == "success"
  end

  it "should parse error response message string" do

    msg_id = RJR::RequestMessage.gen_uuid
    msg_string = '{"id":"' + msg_id + '", ' +
                  '"error":{"code":404,"message":"not found"}, "jsonrpc":"2.0"}'
    msg = RJR::ResponseMessage.new :message => msg_string
    msg.json_message.should == msg_string
    msg.msg_id.should == msg_id
    msg.result.success.should == false
    msg.result.failed.should == true
    msg.result.error_code.should == 404
    msg.result.error_msg.should == "not found"
  end

  it "should extract optional headers from message string" do
    msg_id = RJR::RequestMessage.gen_uuid
    msg_string = '{"id":"' + msg_id + '", ' +
                  '"result":"success","h":2,"jsonrpc":"2.0"}'
    msg = RJR::ResponseMessage.new :message => msg_string
    msg.json_message.should == msg_string
    msg.headers.should have_key 'h'
    msg.headers['h'].should == 2
  end

  it "should fail if parsing invalid message string" do
    lambda {
      msg = RJR::ResponseMessage.new :message => 'foobar'
    }.should raise_error JSON::ParserError
  end
end
