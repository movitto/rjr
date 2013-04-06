require 'rjr/dispatcher'
require 'rjr/util'

describe RJR::Definitions do
  include RJR::Definitions
  
  before(:each) do
    RJR::Dispatcher.init_handlers
    RJR::Definitions.reset
  end

  it "should define methods" do
    foobar = lambda {}
    barfoo = lambda {}
    rjr_method :foobar => foobar, :barfoo => barfoo
    RJR::Dispatcher.handler_for('foobar').handler_proc.should == foobar
    RJR::Dispatcher.handler_for('barfoo').handler_proc.should == barfoo
  end

  it "should track messages" do
    rjr_message :foobar => { :foo => :bar }
    rjr_message('foobar').should == {:foo => :bar}

    rjr_message :foobar => { :bar => :foo }
    rjr_message('foobar').should == {:bar => :foo}

    rjr_message('money').should be_nil
  end

  it "should generate random message" do
    rjr_message :foobar => { :foo => :bar, :transports => [:local, :amqp] }
    rjr_message :barfoo => { :bar => :foo, :transports => [:local] }
    rjr_message :forzzy => { :for => :zzy, :transports => [:amqp] }
    rjr_message :moneyy => { :mon => :eyy }

    [:foo, :bar, :for, :mon].should include(RJR::Definitions::rand_msg.first.first)
    [:foo, :bar, :mon].should include(RJR::Definitions::rand_msg(:local).first.first)
    [:foo, :for, :mon].should include(RJR::Definitions::rand_msg(:amqp).first.first)
    RJR::Definitions::rand_msg(:tcp).first.first.should == :mon

    RJR::Definitions.reset
    rjr_message :foobar => { :foo => :bar, :transports => [:local, :amqp] }

    RJR::Definitions::rand_msg(:tcp).should == nil
  end
end
