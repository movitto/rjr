require 'rjr/amqp_node'
require 'rjr/dispatcher'

describe RJR::AMQPNode do
  it "should invoke and satisfy amqp requests" do
    # XXX since server/client use same em reactor set keep alive true so
    # client doesn't block after receiving request
    server = RJR::AMQPNode.new :node_id => 'amqp', :broker => 'localhost'
    client = RJR::AMQPNode.new :node_id => 'client', :broker => 'localhost', :keep_alive => true

    foozbar_invoked = false
    RJR::Dispatcher.init_handlers
    RJR::Dispatcher.add_handler('foozbar') { |param|
      @client_ip.should == nil
      @client_port.should == nil
      @rjr_node.should == server
      @rjr_node_id.should == 'amqp'
      @rjr_node_type.should == :amqp
      param.should == 'myparam'
      foozbar_invoked = true
      'retval'
    }

    server.listen
    res = client.invoke_request 'amqp-queue', 'foozbar', 'myparam'
    server.halt
    server.join
    res.should == 'retval'
    foozbar_invoked.should == true
  end

  # TODO ensure closed / error event handlers are invoked
end
