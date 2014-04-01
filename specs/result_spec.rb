require 'rjr/result'

module RJR
  describe Result do
    describe "#initialize" do
      it "initializes default attributes" do
        result = Result.new
        result.result.should be_nil
        result.error_code.should be_nil
        result.error_msg.should be_nil
        result.error_class.should be_nil
      end

      it "stores result" do
        result = Result.new :result => 'foobar'
        result.result.should == 'foobar'
      end

      it "stores error" do
        result = Result.new :error_code => 123, :error_msg => 'abc',
                            :error_class => ArgumentError
        result.error_code.should == 123
        result.error_msg.should == 'abc'
        result.error_class.should == ArgumentError
      end

      context "when an error code is not specified" do
        it "should be marked as successful" do
          result = Result.new
          result.success.should == true
          result.failed.should  == false
        end
      end

      context "when an error code is specified" do
        it "should be marked as failed" do
          result = Result.new :error_code => 123
          result.success.should == false
          result.failed.should  == true
        end
      end

    end # describe #initialize

    describe "#==" do
      it "return true for equal results"
      it "return false for inequal results"
    end # descirbe #==

  end # describe Result
end # module RJR
