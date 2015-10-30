require 'rjr/util/handles_methods'
require 'rjr/dispatcher'

module RJR
  class HandlesMethodsTest
    include HandlesMethods

    jr_method :method1
    jr_method :method2, :method3

    jr_method :method4, :custom
    jr_method :method5, :method6, :custom

    def custom
      @foo
    end
  end

  describe HandlesMethods do
    before(:each) do
      @handlers = HandlesMethodsTest.jr_handlers
      HandlesMethodsTest.jr_handlers = Hash[@handlers] if !!@handlers
    end

    after(:each) do
      HandlesMethodsTest.jr_handlers = @handlers
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

    describe "#has_handler_for?" do
      before(:each) do
        HandlesMethodsTest.jr_handlers = {:handle => proc{}}
      end

      context "handler exists" do
        it "returns true" do
          HandlesMethodsTest.has_handler_for?(:handle).should be_truthy
        end
      end

      context "handler does not exist" do
        it "returns false" do
          HandlesMethodsTest.has_handler_for?(:foobar).should be_falsey
        end
      end
    end

    describe "#handler_for" do
      before(:each) do
        HandlesMethodsTest.jr_handlers = {:custom => 'foobar'}
      end

      it "returns handler" do
        HandlesMethodsTest.handler_for(:custom).should == 'foobar'
      end
    end

    describe "#create_handler_for" do
      it "store handler proc in handler registry" do
        HandlesMethodsTest.create_handler_for(:foobar)
        HandlesMethodsTest.jr_handlers[:foobar].should be_an_instance_of(Proc)
      end

      it "returns handler proc" do
        HandlesMethodsTest.create_handler_for(:foobar).should ==
          HandlesMethodsTest.jr_handlers[:foobar]
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
          HandlesMethodsTest.should_receive(:new).twice.and_return(inst)
          inst.should_receive(:custom).twice.with(42)
          HandlesMethodsTest.create_handler_for(:custom).call 42
          HandlesMethodsTest.jr_handlers[:custom].call 42
        end

        it "returns handler return value" do
          @foo = 'bar'
          instance_exec(&HandlesMethodsTest.create_handler_for(:custom)).should == @foo
        end
      end
    end

    describe "#jr_method" do
      it "registers json-rpc methods for later evaluation" do
        args = HandlesMethodsTest.instance_variable_get(:@jr_method_args)
        args.should == [[:method1], [:method2, :method3],
                        [:method4, :custom], [:method5, :method6, :custom]]
      end
    end

    describe "#dispatch_to" do
      it "registers json-rpc method with new handler" do
        d = Dispatcher.new
        HandlesMethodsTest.jr_handlers.should be_nil
        HandlesMethodsTest.dispatch_to(d)
        HandlesMethodsTest.jr_handlers.size.should == 2
        HandlesMethodsTest.jr_handlers[:handle].should be_an_instance_of(Proc)
        HandlesMethodsTest.jr_handlers[:custom].should be_an_instance_of(Proc)
      end

      it "registers local json rpc methods with dispatcher" do
        d = Dispatcher.new
        HandlesMethodsTest.dispatch_to(d)

        d.handler_for('method1').should == HandlesMethodsTest.jr_handlers[:handle]
        d.handler_for('method2').should == HandlesMethodsTest.jr_handlers[:handle]
        d.handler_for('method3').should == HandlesMethodsTest.jr_handlers[:handle]
        d.handler_for('method4').should == HandlesMethodsTest.jr_handlers[:custom]
        d.handler_for('method5').should == HandlesMethodsTest.jr_handlers[:custom]
        d.handler_for('method6').should == HandlesMethodsTest.jr_handlers[:custom]
      end
    end
  end
end
