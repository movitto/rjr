require 'rjr/nodes/tcp'

module RJR::Nodes
  describe TCP do
    describe "#send_msg" do
      it "should send message using the specifed connection"
    end

    describe "#listen" do
      it "should listen for messages" do
        ci = cp = rn = rni = rnt = p = invoked = nil
        server  = TCP.new :node_id => 'tcp',
                          :host => 'localhost', :port => 9987
        server.dispatcher.handle('foobar') { |param|
          ci  = @rjr_client_ip
          cp  = @rjr_client_port
          rn  = @rjr_node
          rni = @rjr_node_id
          rnt = @rjr_node_type
          p   = param
          invoked = true
        }
        server.listen

        # issue request
        TCP.new.invoke 'jsonrpc://localhost:9987', 'foobar', 'myparam'
        server.halt.join
        ci.should == "127.0.0.1"
        #cp.should == 9987
        rn.should == server
        rni.should == 'tcp'
        rnt.should == :tcp
        p.should == 'myparam'
        invoked.should == true
      end
    end

    context "simple server" do
      let(:server) do
        TCP.new(:node_id => 'tcp',
                :host => 'localhost',
                :port => 9987)
      end

      let(:client) { TCP.new }

      before(:each) do
        server.dispatcher.handle('foobar') { |param| 'retval' }
        server.listen
      end

      describe "#invoke" do
        it "should invoke request" do
          res = client.invoke 'jsonrpc://localhost:9987', 'foobar', 'myparam'
          server.halt.join
          res.should == 'retval'
        end
      end

      describe "#notify" do
        it "should send notification" do
          res = client.notify 'jsonrpc://localhost:9987', 'foobar', 'myparam'
          server.halt.join
          res.should == nil
        end
      end
    end

    # TODO test callbacks over tcp interface
    # TODO ensure closed / error event handlers are invoked
  end
end
