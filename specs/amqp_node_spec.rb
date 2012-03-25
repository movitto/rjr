require 'rjr/amqp_node'
require 'rjr/dispatcher'

describe RJR::AMQPNode do
  it "should invoke and satisfy amqp requests" do
    foozbar_invoked = false
    RJR::Dispatcher.init_handlers
    RJR::Dispatcher.add_handler('foozbar') { |param|
      @rjr_node_id.should == 'amqp'
      @rjr_node_type.should == :amqp
      param.should == 'myparam'
      foozbar_invoked = true
      'retval'
    }

    server = RJR::AMQPNode.new :node_id => 'amqp', :broker => 'localhost'
    server.listen
    client = RJR::AMQPNode.new :node_id => 'client', :broker => 'localhost'
    res = client.invoke_request 'amqp-queue', 'foozbar', 'myparam'
    server.halt
    server.join
    res.should == 'retval'
    foozbar_invoked.should == true
  end
end
