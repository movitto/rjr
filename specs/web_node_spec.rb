require 'rjr/web_node'
require 'rjr/dispatcher'

describe RJR::WebNode do
  it "should invoke and satisfy http requests" do
    foobar_invoked = false
    RJR::Dispatcher.init_handlers
    RJR::Dispatcher.add_handler('foobar') { |param|
      @client_ip.should == "127.0.0.1"
      #@client_port.should == 9678
      @rjr_node_id.should == 'www'
      @rjr_node_type.should == :web
      param.should == 'myparam'
      foobar_invoked = true
      'retval'
    }

    server = RJR::WebNode.new :node_id => 'www', :host => 'localhost', :port => 9678
    server.listen

    client = RJR::WebNode.new
    res = client.invoke_request 'http://localhost:9678', 'foobar', 'myparam'
    res.should == 'retval'
    server.halt

    server.join
    foobar_invoked.should == true
  end
end
