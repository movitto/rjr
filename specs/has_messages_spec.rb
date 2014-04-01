require 'rjr/has_messages'

module RJR
  class HasMessagesTest
    include HasMessages
  end

  describe HasMessages do
    after(:each) do
      HasMessagesTest.clear
    end

    describe "#define_message" do
      it "defines new message" do
        HasMessagesTest.new.define_message('foobar') { 'barfoo' }
        HasMessagesTest.message('foobar').should == 'barfoo'
      end
    end

    describe "::message" do
      it "sets/gets message" do
        HasMessagesTest.message('foobar', 'barfoo')
        HasMessagesTest.message('foobar').should == 'barfoo'
      end
    end

    describe "::clear" do
      it "clears messages" do
        HasMessagesTest.message('foobar', 'barfoo')
        HasMessagesTest.clear
        HasMessagesTest.message('foobar').should be_nil
      end
    end

    describe "#rand_msg" do
      it "returns random message" do
        msg1 = {}
        msg2 = {}
        HasMessagesTest.message('foobar', msg1)
        HasMessagesTest.message('barfoo', msg2)
        HasMessagesTest.should_receive(:rand).and_return(1)
        HasMessagesTest.rand_msg.should == msg2
      end

      it "returns random message matching specified transport" do
        tcpm  = {:transports => ['tcp']}
        amqpm = {:transports => ['amqp']}
        HasMessagesTest.message('foobar', tcpm)
        HasMessagesTest.message('barfoo', amqpm)
        HasMessagesTest.rand_msg('tcp').should == tcpm
      end
    end
  end # describe HasMessages
end # module RJR
