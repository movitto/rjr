require 'rjr/nodes/ws_node'
require 'rjr/dispatcher'

describe RJR::WSNode do
  it "should invoke and satisfy websocket requests" do
    server = RJR::WSNode.new :node_id => 'ws', :host => 'localhost', :port => 9876
    client = RJR::WSNode.new

    foobar_invoked = false
    RJR::Dispatcher.init_handlers
    RJR::Dispatcher.add_handler('foobar') { |param|
      @client_ip.should == "127.0.0.1"
      #@client_port.should == 9678
      @rjr_node.should == server
      @rjr_node_id.should == 'ws'
      @rjr_node_type.should == :ws
      param.should == 'myparam'
      foobar_invoked = true
      'retval'
    }

    server.listen
    sleep 1
    res = client.invoke_request 'ws://localhost:9876', 'foobar', 'myparam'
    res.should == 'retval'
    server.halt
    server.join
    foobar_invoked.should == true
  end

  # TODO ensure closed / error event handlers are invoked
end
