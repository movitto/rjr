require 'rjr/dispatcher'
require 'rjr/message'

module RJR
  describe RequestMessage do
    it "should accept request parameters" do
      msg = RequestMessage.new :method => 'test',
                               :args   => ['a', 1],
                               :headers => {:h => 2}
      msg.jr_method.should == "test"
      msg.jr_args.should =~ ['a', 1]
      msg.headers.should have_key(:h)
      msg.headers[:h].should == 2
      msg.msg_id.should =~ /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/
    end

    it "should return bool indicating if string is a request msg"

    it "should produce valid json" do
      msg = RequestMessage.new :method => 'test',
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
      msg_uuid = gen_uuid 
      msg_string = '{"jsonrpc": "2.0", ' +
                   '"id": "' + msg_uuid + '", ' +
                   '"method": "test", "params": ["a", 1]}'
      msg = RequestMessage.new :message => msg_string
      msg.json_message.should == msg_string
      msg.jr_method.should == 'test'
      msg.jr_args.should =~ ['a', 1]
      msg.msg_id.should == msg_uuid
    end

    it "should extract optional headers from message string" do
      msg_uuid = gen_uuid 
      msg_string = '{"jsonrpc": "2.0", ' +
                   '"id": "' + msg_uuid + '", ' +
                   '"method": "test", "params": ["a", 1], ' +
                   '"h": 2}'
      msg = RequestMessage.new :message => msg_string, :headers => {'f' => 'g'}
      msg.json_message.should == msg_string
      msg.headers.should have_key 'h'
      msg.headers.should have_key 'f'
      msg.headers['h'].should == 2
      msg.headers['f'].should == 'g'
    end

    it "should fail if parsing invalid message string" do
      lambda {
        msg = RequestMessage.new :message => 'foobar'
      }.should raise_error JSON::ParserError
    end

  end

  describe ResponseMessage do
    it "should accept response parameters" do
      msg_id = gen_uuid
      msg = ResponseMessage.new :id      => msg_id,
                                     :result  => Result.new(:result => 'success'),
                                     :headers => {:h => 2}
      msg.msg_id.should == msg_id
      msg.result.result == 'success'
      msg.headers.should have_key(:h)
      msg.headers[:h].should == 2
    end

    it "should return bool indicating if string is a response msg"

    it "should produce valid result response json" do
      msg_id = gen_uuid
      msg = ResponseMessage.new :id      => msg_id,
                                :result  => RJR::Result.new(:result => 'success'),
                                :headers => {:h => 2}
      msg_string = msg.to_s
      msg_string.should include('"id":"'+msg_id+'"')
      msg_string.should include('"result":"success"')
      msg_string.should include('"h":2')
      msg_string.should include('"jsonrpc":"2.0"')
    end

    it "should produce valid error response json" do
      msg_id = gen_uuid
      msg = ResponseMessage.new :id      => msg_id,
                                :result  =>
                                  RJR::Result.new(:error_code => 404,
                                                  :error_msg => 'not found',
                                                  :error_class => ArgumentError),
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
      msg_id = gen_uuid
      msg_string = '{"id":"' + msg_id + '", ' +
                    '"result":"success","jsonrpc":"2.0"}'
      msg = ResponseMessage.new :message => msg_string
      msg.json_message.should == msg_string
      msg.msg_id.should == msg_id
      msg.result.success.should == true
      msg.result.failed.should == false
      msg.result.result.should == "success"
    end

    it "should parse error response message string" do
      msg_id = gen_uuid
      msg_string = '{"id":"' + msg_id + '", ' +
                    '"error":{"code":404,"message":"not found","class":"ArgumentError"}, "jsonrpc":"2.0"}'
      msg = ResponseMessage.new :message => msg_string
      msg.json_message.should == msg_string
      msg.msg_id.should == msg_id
      msg.result.success.should == false
      msg.result.failed.should == true
      msg.result.error_code.should == 404
      msg.result.error_msg.should == "not found"
      msg.result.error_class.should == 'ArgumentError'
    end

    it "should extract optional headers from message string" do
      msg_id = gen_uuid
      msg_string = '{"id":"' + msg_id + '", ' +
                    '"result":"success","h":2,"jsonrpc":"2.0"}'
      msg = ResponseMessage.new :message => msg_string
      msg.json_message.should == msg_string
      msg.headers.should have_key 'h'
      msg.headers['h'].should == 2
    end

    it "should fail if parsing invalid message string" do
      lambda {
        msg = ResponseMessage.new :message => 'foobar'
      }.should raise_error JSON::ParserError
    end
  end

  describe NotificationMessage do
    it "should accept notification parameters" do
      msg = NotificationMessage.new :method => 'test',
                                    :args   => ['a', 1],
                                    :headers => {:h => 2}
      msg.jr_method.should == "test"
      msg.jr_args.should =~ ['a', 1]
      msg.headers.should have_key(:h)
      msg.headers[:h].should == 2
    end

    it "should return bool indicating if string is a notification msg"
  
    it "should produce valid json" do
      msg = NotificationMessage.new :method => 'test',
                                    :args   => ['a', 1],
                                    :headers => {:h => 2}
  
      msg_string = msg.to_s
      msg_string.should include('"h":2')
      msg_string.should include('"method":"test"')
      msg_string.should include('"params":["a",1]')
      msg_string.should include('"jsonrpc":"2.0"')
      msg_string.should_not include('"id":"')
    end
  
    it "should parse notification message string" do
      msg_string = '{"jsonrpc": "2.0", ' +
                   '"method": "test", "params": ["a", 1]}'
      msg = NotificationMessage.new :message => msg_string
      msg.json_message.should == msg_string
      msg.jr_method.should == 'test'
      msg.jr_args.should =~ ['a', 1]
    end
  
    it "should extract optional headers from message string" do
      msg_string = '{"jsonrpc": "2.0", ' +
                   '"method": "test", "params": ["a", 1], ' +
                   '"h": 2}'
      msg = NotificationMessage.new :message => msg_string, :headers => {'f' => 'g'}
      msg.json_message.should == msg_string
      msg.headers.should have_key 'h'
      msg.headers.should have_key 'f'
      msg.headers['h'].should == 2
      msg.headers['f'].should == 'g'
    end
  
    it "should fail if parsing invalid message string" do
      lambda {
        msg = NotificationMessage.new :message => 'foobar'
      }.should raise_error JSON::ParserError
    end
  end

  describe MessageUtil do
    after(:each) do
      MessageUtil.clear
    end

    it "should extract json messages out of a message stream"

    it "should store preformatted messages" do
      MessageUtil.message 'foobar', 'raboof'
      MessageUtil.message('foobar').should == 'raboof'
    end

    it "should clear preformatted messages" do
      MessageUtil.message 'foobar', 'raboof'
      MessageUtil.clear
      MessageUtil.message('foobar').should be_nil
    end

    it "should return rand preformatted message"
    it "should return rand preformatted message matching transport"
  end

end
