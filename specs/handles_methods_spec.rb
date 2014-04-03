require 'rjr/util/handles_methods'
require 'rjr/dispatcher'

module RJR
  class HandlesMethodsTest
    include HandlesMethods

    def custom
      @foo
    end

    jr_method :method1
    jr_method :method2, :method3

    jr_method :method4, :custom
    jr_method :method5, :method6, :custom

  end

  describe HandlesMethods do
    before(:each) do
      @handlers = HandlesMethodsTest.instance_variable_get(:@jr_handlers)
    end

    describe "#extract_handler_method" do
      context "args.last is a class method" do
        it "returns args.last" do
          result = HandlesMethodsTest.extract_handler_method([:method1, :custom])
          result[0].should == :custom
        end

        it "returns argument list with args.last removed" do
          result = HandlesMethodsTest.extract_handler_method([:method1, :custom])
          result[1].should == [:method1]
        end
      end

      context "args.last is not a class method" do
        it "returns :handle" do
          result = HandlesMethodsTest.extract_handler_method([:method1])
          result[0].should == :handle
        end

        it "returns argument list" do
          result = HandlesMethodsTest.extract_handler_method([:method1])
          result[1].should == [:method1]
        end
      end
    end

    describe "#has_handler_for" do
      context "handler exists" do
        it "returns true" do
          HandlesMethodsTest.has_handler_for?(:handle).should be_true
          HandlesMethodsTest.has_handler_for?(:custom).should be_true
        end
      end

      context "handler does not exist" do
        it "returns false" do
          HandlesMethodsTest.has_handler_for?(:foobar).should be_false
        end
      end
    end

    describe "#handler_for" do
      before(:each) do
        @orig_handler = @handlers[:custom]
        @handlers[:custom] = 'foobar'
      end

      after(:each) do
        @handlers[:custom] = @orig_handler
      end

      it "returns handler" do
        HandlesMethodsTest.handler_for(:custom).should == 'foobar'
      end
    end

    describe "#create_handler_for" do
      before(:each) do
        @orig_handlers = HandlesMethodsTest.instance_variable_get(:@jr_handlers)
        @new_handlers  = Hash[@orig_handlers]
        HandlesMethodsTest.instance_variable_set(:@jr_handlers, @new_handlers)
      end

      after(:each) do
        HandlesMethodsTest.instance_variable_set(:@jr_handlers, @orig_handlers)
      end

      it "store handler proc in handler registry" do
        HandlesMethodsTest.create_handler_for(:foobar)
        @new_handlers[:foobar].should be_an_instance_of(Proc)
      end

      it "returns handler proc" do
        HandlesMethodsTest.create_handler_for(:foobar).should == @new_handlers[:foobar]
      end

      describe "handler" do
        it "instantiates handler class" do
          HandlesMethodsTest.should_receive(:new).and_call_original
          HandlesMethodsTest.create_handler_for(:custom).call
        end

        it "sets local instance_variables on instance" do
          @foo = 'bar'
          inst = HandlesMethodsTest.new
          HandlesMethodsTest.should_receive(:new).and_return(inst)
          instance_exec &HandlesMethodsTest.create_handler_for(:custom)
          inst.instance_variable_get(:@foo).should == 'bar'
        end

        it "invokes handler method with args" do
          inst = HandlesMethodsTest.new
          HandlesMethodsTest.should_receive(:new).and_return(inst)
          inst.should_receive(:custom).with(42)
          @new_handlers[:custom].call 42
        end

        it "returns handler return value" do
          @foo = 'bar'
          instance_exec(&HandlesMethodsTest.create_handler_for(:custom)).should == @foo
        end
      end
    end

    describe "#jr_method" do
      it "registers json-rpc method with default handler" do
        expected = [[:method1], @handlers[:handle]]
        HandlesMethodsTest.jr_methods[0].should == expected
      end

      it "registers json-rpc methods with default handler" do
        expected = [[:method2, :method3], @handlers[:handle]]
        HandlesMethodsTest.jr_methods[1].should == expected
      end

      it "registers json-rpc method with custom handler" do
        expected = [[:method4], @handlers[:custom]]
        HandlesMethodsTest.jr_methods[2].should == expected
      end

      it "registers json-rpc methods with custom handler" do
        expected = [[:method5, :method6], @handlers[:custom]]
        HandlesMethodsTest.jr_methods[3].should == expected
      end
    end

    describe "#dispatch_to" do
      it "registers local json rpc methods with dispatcher" do
        d = Dispatcher.new
        d.should_receive(:handle).with([:method1], @handlers[:handle])
        d.should_receive(:handle).with([:method2, :method3], @handlers[:handle])
        d.should_receive(:handle).with([:method4], @handlers[:custom])
        d.should_receive(:handle).with([:method5, :method6], @handlers[:custom])
        HandlesMethodsTest.dispatch_to(d)
      end
    end
  end
end
