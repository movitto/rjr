require 'rjr/common'
require 'rjr/result'
require 'rjr/messages/response'

module RJR
module Messages
  describe Response do
    it "should accept response parameters" do
      msg_id = gen_uuid
      msg = Response.new :id      => msg_id,
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
      msg = Response.new :id      => msg_id,
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
      msg = Response.new :id      => msg_id,
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
      msg = Response.new :message => msg_string
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
      msg = Response.new :message => msg_string
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
      msg = Response.new :message => msg_string
      msg.json_message.should == msg_string
      msg.headers.should have_key 'h'
      msg.headers['h'].should == 2
    end

    it "should fail if parsing invalid message string" do
      lambda {
        msg = Response.new :message => 'foobar'
      }.should raise_error JSON::ParserError
    end
  end # describe Response
end # module Messages
end # module RJR
