require 'rjr/amqp_node'

describe RJR::AMQPNode do
  it "should invoke and satisfy amqp requests" do
    foobar_invoked = false
    RJR::Dispatcher.init_handlers
    RJR::Dispatcher.add_handler('foobar') { |param|
      @rjr_node_id.should == 'amqp'
      @rjr_node_type.should == :amqp
      param.should == 'myparam'
      foobar_invoked = true
      'retval'
    }

    server = RJR::AMQPNode.new :node_id => 'amqp', :broker => 'localhost'
    server.em_run do
      server.listen

      Thread.new {
        client = RJR::AMQPNode.new :node_id => 'client', :broker => 'localhost'
        res = client.invoke_request 'amqp-queue', 'foobar', 'myparam'
        res.should == 'retval'
        EventMachine.stop_event_loop
      }
    end
    foobar_invoked.should == true
  end
end
