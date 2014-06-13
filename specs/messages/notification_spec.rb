require 'rjr/messages/notification'
require 'rjr/messages/intermediate'

module RJR
module Messages
  describe Notification do
    it "should accept notification parameters" do
      msg = Notification.new :method => 'test',
                                    :args   => ['a', 1],
                                    :headers => {:h => 2}
      msg.jr_method.should == "test"
      msg.jr_args.should =~ ['a', 1]
      msg.headers.should have_key(:h)
      msg.headers[:h].should == 2
    end

    it "should return bool indicating if string is a notification msg"
  
    it "should produce valid json" do
      msg = Notification.new :method  => 'test',
                             :args    => ['a', 1],
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
      inter = Intermediate.parse msg_string

      msg = Notification.new :message => inter
      msg.message.should == inter
      msg.jr_method.should == 'test'
      msg.jr_args.should =~ ['a', 1]
    end
  
    it "should extract optional headers from message string" do
      msg_string = '{"jsonrpc": "2.0", ' +
                   '"method": "test", "params": ["a", 1], ' +
                   '"h": 2}'
      inter = Intermediate.parse msg_string

      msg = Notification.new :message => inter, :headers => {'f' => 'g'}
      msg.message.should == inter
      msg.headers.should have_key 'h'
      msg.headers.should have_key 'f'
      msg.headers['h'].should == 2
      msg.headers['f'].should == 'g'
    end
  end # describe Notification
end # module Messages
end # module RJR
