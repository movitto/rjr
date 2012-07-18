require 'rjr/ws_node'
require 'rjr/dispatcher'

describe RJR::WSNode do
  it "should invoke and satisfy websocket requests" do
    foobar_invoked = false
    RJR::Dispatcher.init_handlers
    RJR::Dispatcher.add_handler('foobar') { |param|
      @client_ip.should == "127.0.0.1"
      #@client_port.should == 9678
      @rjr_node_id.should == 'ws'
      @rjr_node_type.should == :websockets
      param.should == 'myparam'
      foobar_invoked = true
      'retval'
    }

    server = RJR::WSNode.new :node_id => 'ws', :host => 'localhost', :port => 9876
    server.listen
    client = RJR::WSNode.new
    res = client.invoke_request 'ws://localhost:9876', 'foobar', 'myparam'
    res.should == 'retval'
    server.halt
    server.join
    foobar_invoked.should == true
  end
end
