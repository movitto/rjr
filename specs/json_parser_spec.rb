require 'rjr/util/json_parser'
require 'rjr/core_ext'

module RJR
describe JSONParser do
  describe "#extract_json_from" do
    it "returns first json object from string" do
      json = '{"foo":"bar"}'
      JSONParser.extract_json_from(json).should == [json, '']
    end

    it "returns remaining portion of string" do
      json = '{"foo":"bar"}'
      complete = "#{json}remaining"
      JSONParser.extract_json_from(complete).should == [json, 'remaining']
    end

    it "handles brackets in quoted data" do
      json = '{"foo":"val{"}'
      JSONParser.extract_json_from(json).should == [json, '']
    end

    it "handles nested quotes" do
      json = '{"foo":"val\'{\'"}'
      JSONParser.extract_json_from(json).should == [json, '']
    end

    it "handles uneven quotes" do
      json = '{"foo":"val\'"}'
      JSONParser.extract_json_from(json).should == [json, '']
    end

    it "handles escaped quotes" do
      json = '{"foo":"val\\""}'
      JSONParser.extract_json_from(json).should == [json, '']
    end

    it "handles escaped chars" do
      json = '{"foo":"val\\\\"}'
      JSONParser.extract_json_from(json).should == [json, '']
    end
  end

  describe "#invalid_json_class?" do
    before(:each) do
      @orig_whitelist = Class.whitelist_json_classes
    end

    after(:each) do
      Class.whitelist_json_classes = @orig_whitelist
    end

    context "json class whitelisting enabled" do
      before(:each) do
        Class.whitelist_json_classes = true
      end

      context "class not on permitted classes list" do
        it "returns true" do
          Class.should_receive(:permitted_json_classes).and_return([])
          JSONParser.invalid_json_class?('foobar').should be_truthy
        end
      end

      context "class on permitted classes list" do
        it "returns false" do
          Class.should_receive(:permitted_json_classes).and_return(['foobar'])
          JSONParser.invalid_json_class?('foobar').should be_falsey
        end
      end
    end

    context "json class whitelisting not enabled" do
      before(:each) do
        Class.whitelist_json_classes = false
      end

      context "class not on ruby heirarchy" do
        it "returns true" do
          JSONParser.invalid_json_class?('Foobar').should be_truthy
        end
      end

      context "class on ruby heirarchy" do
        it "returns false" do
          JSONParser.invalid_json_class?('Integer').should be_falsey
        end
      end
    end
  end

  describe "#validate_json_hash" do
    context "a hash key is the JSON.create_id and value is invalid class" do
      it "raises argument error" do
        hash = {JSON.create_id => 'foobar'}
        JSONParser.should_receive(:invalid_json_class?).
                   with('foobar').and_return(true)
        lambda{
          JSONParser.validate_json_hash(hash)
        }.should raise_error(ArgumentError)
      end
    end

    context "a value is an array" do
      it "validates json array" do
        arr  = []
        hash = {'foobar' => arr}
        JSONParser.should_receive(:validate_json_array).with(arr)
        JSONParser.validate_json_hash(hash)
      end
    end

    context "a value is a hash" do
      it "validates json hash" do
        inner  = {}
        hash = {'foobar' => inner}
        JSONParser.should_receive(:validate_json_hash).with(hash).and_call_original
        JSONParser.should_receive(:validate_json_hash).with(inner)
        JSONParser.validate_json_hash(hash)
      end
    end
  end

  describe "#validate_json_array" do
    context "a value is an array" do
      it "validates json array" do
        inner = []
        array = [inner]
        JSONParser.should_receive(:validate_json_array).with(array).and_call_original
        JSONParser.should_receive(:validate_json_array).with(inner)
        JSONParser.validate_json_array(array)
      end
    end

    context "a value is a hash" do
      it "validates json hash" do
        inner = {}
        array = [inner]
        JSONParser.should_receive(:validate_json_hash).with(inner)
        JSONParser.validate_json_array(array)
      end
    end
  end

  describe "#parse" do
    before(:each) do
      @json = '{"foo":"bar"}'
    end

    it "safely parses json" do
      JSON.should_receive(:parse).
           with(@json, :create_additions => false).and_call_original
      JSON.should_receive(:parse).once
      JSONParser.parse(@json)
    end

    context "json is an array" do
      it "validates json array" do
        arr = []
        JSON.should_receive(:parse).and_return(arr)
        JSON.should_receive(:parse).once
        JSONParser.should_receive(:validate_json_array).with(arr)
        JSONParser.parse(@json)
      end
    end

    context "json is a hash" do
      it "validates json hash" do
        hash = {}
        JSON.should_receive(:parse).and_return(hash)
        JSON.should_receive(:parse).once
        JSONParser.should_receive(:validate_json_hash).with(hash)
        JSONParser.parse(@json)
      end
    end

    context "json is not a array/hash" do
      it "returns value" do
        JSON.should_receive(:parse).and_return(42)
        JSONParser.parse(@json).should == 42
      end
    end

    it "parses json, creating classes" do
      njs = {}
      JSON.should_receive(:parse).
           with(@json, :create_additions => false).and_call_original
      JSON.should_receive(:parse).
           with(@json, :create_additions => true).
           and_return(njs)
      JSONParser.parse(@json).should == njs
    end
  end
end # describe JSONParser
end # module RJR
