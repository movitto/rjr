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
      context "all fields are equal" do
        it "returns true" do
          Result.new.should == Result.new
          Result.new(:result => 1).should == Result.new(:result => 1)
          Result.new(:error_code => 50).should == Result.new(:error_code => 50)
        end
      end

      context "'success' is different" do
        it "returns false" do
          r1 = Result.new
          r2 = Result.new
          r1.success = true
          r2.success = false
          r1.should_not == r2
        end
      end

      context "'failed' is different" do
        it "returns false" do
          r1 = Result.new
          r2 = Result.new
          r1.failed = true
          r2.failed = false
          r1.should_not == r2
        end
      end

      context "'result' is different" do
        it "returns false" do
          r1 = Result.new
          r2 = Result.new
          r1.result = 1
          r2.result = 2
          r1.should_not == r2
        end
      end

      context "'error_code' is different" do
        it "returns false" do
          r1 = Result.new
          r2 = Result.new
          r1.error_code = 1
          r2.error_code = 2
          r1.should_not == r2
        end
      end

      context "'error_msg' is different" do
        it "returns false" do
          r1 = Result.new
          r2 = Result.new
          r1.error_msg = 'something'
          r2.error_msg = 'bad'
          r1.should_not == r2
        end
      end

      context "'error_class' is different" do
        it "returns false" do
          r1 = Result.new
          r2 = Result.new
          r1.error_class = 'something'
          r2.error_class = 'bad'
          r1.should_not == r2
        end
      end
    end # describe #==

    describe "#invalid_request" do
      it "is an instance of result" do
        Result.invalid_request.should be_an_instance_of(Result)
      end

      it "has error code -32600" do
        Result.invalid_request.error_code.should == -32600
      end

      it "has error message 'Invalid Request'" do
        Result.invalid_request.error_msg.should == "Invalid Request"
      end
    end

    describe "#method_not_found" do
      it "is an instance of result" do
        Result.method_not_found('foobar').should be_an_instance_of(Result)
      end

      it "has error code -32602" do
        Result.method_not_found('foobar').error_code.should == -32602
      end

      it "has error message 'Method '<name>' not found'" do
        Result.method_not_found('foobar').error_msg.should ==
          "Method 'foobar' not found"
      end
    end

  end # describe Result
end # module RJR
