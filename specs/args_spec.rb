require 'rjr/args'

module RJR
  describe Arguments do
    describe "#intialize" do
      it "initializes arguments" do
        a = Arguments.new :args => [42]
        a.args.should == [42]
      end
    end

    describe "#validate!" do
      context "acceptable is a hash" do
        context "at least one argument not in acceptable hash keys" do
          it "raises an ArgumentError" do
            a = Arguments.new :args => ['invalid', 42]
            expect {
              a.validate! 'valid' => 1
            }.to raise_error(ArgumentError)
          end
        end

        context "all arguments are in acceptable hash keys" do
          it "does not raise an error" do
            a = Arguments.new :args => ['valid', 42]
            expect {
              a.validate! 'valid' => 1
            }.not_to raise_error
          end
        end

        context "no arguments" do
          it "does not raise an error" do
            a = Arguments.new
            expect {
              a.validate! 'valid' => 1
            }.not_to raise_error
          end
        end

        it "converts acceptable keys to strings before comparison" do
           a = Arguments.new :args => ['valid', 42]
           expect {
             a.validate! :valid => 1
           }.not_to raise_error
        end

        it "skips over # of arguments specified by acceptable hash values" do
           a = Arguments.new :args => ['valid', 42]
           expect {
             a.validate! :valid => 1
           }.not_to raise_error

           expect {
             a.validate! :valid => 0
           }.to raise_error(ArgumentError)
        end
      end

      context "acceptable is an array" do
        context "at least one argument not on acceptable list" do
          it "raises an ArgumentError" do
            a = Arguments.new :args => ['invalid']
            expect {
              a.validate! 'valid'
            }.to raise_error(ArgumentError)
          end
        end

        context "all arguments on acceptable list" do
          it "does not raise an error" do
            a = Arguments.new :args => ['valid']
            expect {
              a.validate! 'valid'
            }.not_to raise_error
          end
        end

        context "no arguments" do
          it "does not raise an error" do
            a = Arguments.new
            expect {
              a.validate! 'valid'
            }.not_to raise_error
          end
        end

        it "converts acceptable list to strings before comparison" do
          a = Arguments.new :args => ['valid']
          expect {
            a.validate! :valid
          }.not_to raise_error
        end
      end
    end

    describe "#extract" do
      before(:each) do
        @a = Arguments.new :args => ['match1', 'val1', 'val2',
                                     'match2', 'val2', 'match3']
      end

      it "returns extracted map key & following values from arguments" do
        result = @a.extract 'match1' => 2, 'match3' => 0
        result.should == [['match1', 'val1', 'val2'], ['match3']]
      end

      it "matches symbollic map keys" do
        result = @a.extract :match2 => 1
        result.should == [['match2', 'val2']]
      end
    end

    describe "#specifies?" do
      context "arguments includes tag" do
        it "returns true" do
          a = Arguments.new :args => ['with_id', 42]
          a.specifies?('with_id').should be_true
        end
      end

      context "arguments does not include tag" do
        it "returns false" do
          a = Arguments.new :args => ['with_id', 42]
          a.specifies?('with_name').should be_false
        end
      end
    end

    describe "#specifier_for" do
      it "returns argument at index of tag + 1" do
        a = Arguments.new :args => ['with_id', 42]
        a.specifier_for('with_id').should == 42
      end

      context "arguments do not specify tag" do
        it "returns nil" do
          a = Arguments.new :args => ['with_id', 42]
          a.specifier_for('with_name').should be_nil
        end
      end
    end
  end # describe Arguments
end # module RJR
