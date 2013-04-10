require 'rjr/multi_node'
require 'rjr/amqp_node'
require 'rjr/web_node'
require 'rjr/dispatcher'

describe RJR::MultiNode do
  it "should invoke and satisfy requests over multiple protocols" do
    foolbar_invoked = false
    barfoo_invoked = false
    RJR::Dispatcher.init_handlers
    RJR::Dispatcher.add_handler('foolbar') { |param|
      @rjr_node_id.should == 'amqp'
      @rjr_node_type.should == :amqp
      param.should == 'myparam1'
      foolbar_invoked = true
      'retval1'
    }
    RJR::Dispatcher.add_handler('barfoo') { |param|
      @rjr_node_id.should == 'web'
      @rjr_node_type.should == :web
      param.should == 'myparam2'
      barfoo_invoked = true
      'retval2'
    }

    amqp = RJR::AMQPNode.new :node_id => 'amqp', :broker => 'localhost'
    web  = RJR::WebNode.new :node_id => 'web', :host => 'localhost', :port => 9876
    multi = RJR::MultiNode.new :node_id => 'multi', :nodes => [amqp, web], :keep_alive => true

    multi.listen

    amqp_client = RJR::AMQPNode.new :node_id => 'client', :broker => 'localhost', :keep_alive => true # see comment about keepalive in amqp_node_spec
    res = amqp_client.invoke_request 'amqp-queue', 'foolbar', 'myparam1'
    res.should == 'retval1'

    web_client  = RJR::WebNode.new
    res = web_client.invoke_request 'http://localhost:9876', 'barfoo', 'myparam2'
    res.should == 'retval2'

    multi.halt
    multi.join
    foolbar_invoked.should == true
    barfoo_invoked.should == true
  end
end
