require 'rjr/nodes/ws'
require 'rjr/dispatcher'

module RJR::Nodes
  describe WS do
    describe "#send_msg" do
      it "should send response using the specified connection"
    end

    describe "#listen" do
      it "should listen for messages" do
        ci = cp = rn = rni = rnt = p = invoked = nil
        node = WS.new :node_id => 'ws', :host => 'localhost', :port => 9678
        node.dispatcher.handle('test') do |param|
          ci  = @rjr_client_ip
          cp  = @rjr_client_port
          rn  = @rjr_node
          rni = @rjr_node_id
          rnt = @rjr_node_type
          p   = param
          invoked = true
        end
        node.listen

        # issue request
        WS.new.invoke 'http://localhost:9678', 'test', 'myparam'
        node.halt.join
        invoked.should be_true
        ci.should == '127.0.0.1'
        #cp.should
        rn.should == node
        rni.should == 'ws'
        rnt.should == :ws
        p.should   == 'myparam'
      end
    end

    describe "#invoke" do
      it "should invoke request" do
        server = WS.new :node_id => 'ws', :host => 'localhost', :port => 9678
        server.dispatcher.handle('test') do |p|
          'retval'
        end
        server.listen

        client = WS.new
        res = client.invoke 'http://localhost:9678', 'test', 'myparam'

        server.halt.join
        res.should == 'retval'
      end
    end

    describe "#notify" do
      it "should send notification" do
        server = WS.new :node_id => 'ws', :host => 'localhost', :port => 9678
        server.dispatcher.handle('test') do |p|
          'retval'
        end
        server.listen

        client = WS.new
        res = client.notify 'http://localhost:9678', 'test', 'myparam'

        server.halt.join
        res.should == nil
      end
    end

    # TODO test callbacks over ws interface
    # TODO ensure closed / error event handlers are invoked
  end
end
