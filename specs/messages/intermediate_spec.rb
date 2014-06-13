require 'rjr/common'
require 'rjr/messages/intermediate'

module RJR
module Messages
  describe Intermediate do
    describe "#keys" do
      it "returns extracted data keys" do
        msg = Intermediate.new :data => {:foo => :bar, :mo => :money}
        msg.keys.should == [:foo, :mo]
      end
    end

    describe "#[]" do
      it "returns value from extracted data" do
        msg = Intermediate.new :data => {'foo' => 'bar'}
        msg['foo'].should == 'bar'
        msg[:foo].should == 'bar'
      end
    end

    describe "#has?" do
      context "data has key" do
        it "returns true" do
          msg = Intermediate.new :data => {'foo' => 'bar'}
          msg.has?('foo').should be_true
        end
      end

      context "data does not have key" do
        it "returns false" do
          msg = Intermediate.new
          msg.has?('foo').should be_false
        end
      end
    end

    describe "::parse" do
      it "returns new intermediate instance with original message and parsed data" do
        json = '{"foo":"bar"}'
        msg = Intermediate.parse json
        msg.json.should == json
        msg.data.should == {"foo" => "bar"}
      end

      describe "error parsing json" do
        it "propagates err" do
          json = '{"foo":"bar"}'
          JSONParser.should_receive(:parse).with(json).and_raise(RuntimeError)
          lambda {
            Intermediate.parse json
          }.should raise_error(RuntimeError)
        end
      end
    end
  end # describe Intermediate
end # module Messages
end # module RJR
