require 'rjr/nodes/tcp_node'
require 'rjr/dispatcher'

describe RJR::TCPNode do
  it "should invoke and satisfy tcp requests" do
    server = RJR::TCPNode.new :node_id => 'tcp', :host => 'localhost', :port => 9987
    client = RJR::TCPNode.new

    foobar_invoked = false
    RJR::Dispatcher.init_handlers
    RJR::Dispatcher.add_handler('foobar') { |param|
      @client_ip.should == "127.0.0.1"
      #@client_port.should == 9987
      @rjr_node.should == server
      @rjr_node_id.should == 'tcp'
      @rjr_node_type.should == :tcp
      param.should == 'myparam'
      foobar_invoked = true
      'retval'
    }

    server.listen
    sleep 1
    res = client.invoke_request 'jsonrpc://localhost:9987', 'foobar', 'myparam'
    res.should == 'retval'
    server.halt
    server.join
    foobar_invoked.should == true
  end

  # TODO ensure closed / error event handlers are invoked
  # TODO ensure callbacks can be invoked over established connection w/ json-rpc notifications
end
