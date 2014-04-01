require 'rjr/common'
require 'rjr/messages/request'

module RJR
module Messages
  describe Request do
    it "should accept request parameters" do
      msg = Request.new :method => 'test',
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
      msg = Request.new :method => 'test',
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
      msg = Request.new :message => msg_string
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
      msg = Request.new :message => msg_string, :headers => {'f' => 'g'}
      msg.json_message.should == msg_string
      msg.headers.should have_key 'h'
      msg.headers.should have_key 'f'
      msg.headers['h'].should == 2
      msg.headers['f'].should == 'g'
    end

    it "should fail if parsing invalid message string" do
      lambda {
        msg = Request.new :message => 'foobar'
      }.should raise_error JSON::ParserError
    end
  end # describe Request
end # module Messages
end # module RJR
