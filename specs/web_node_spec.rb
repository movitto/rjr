require 'rjr/web_node'

describe RJR::WebNode do
  it "should invoke and satisfy http requests" do
    foobar_invoked = false
    RJR::Dispatcher.init_handlers
    RJR::Dispatcher.add_handler('foobar') { |param|
      @rjr_node_id.should == 'www'
      @rjr_node_type.should == :web
      param.should == 'myparam'
      foobar_invoked = true
      'retval'
    }

    server = RJR::WebNode.new :node_id => 'www', :host => 'localhost', :port => 9876
    server.em_run do
      server.listen

      Thread.new{
        client = RJR::WebNode.new
        res = client.invoke_request 'http://localhost:9876', 'foobar', 'myparam'
        res.should == 'retval'
        EventMachine.stop_event_loop
      }
    end
    foobar_invoked.should == true
  end
end
