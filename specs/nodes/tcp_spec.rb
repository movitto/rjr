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

      let(:host) { 'jsonrpc://localhost:9987' }

      let(:client) { TCP.new }

      before(:each) do
        server.dispatcher.handle('foobar') { |param| 'retval' }
        server.listen
      end

      describe "#invoke" do
        it "should invoke request" do
          res = client.invoke host, 'foobar', 'myparam'
          server.halt.join
          res.should == 'retval'
        end
      end

      describe "#notify" do
        it "should send notification" do
          res = client.notify host, 'foobar', 'myparam'
          server.halt.join
          res.should == nil
        end
      end

      describe "a node's connections array" do
        it "should be updated when a connection is opened" do
          client.invoke host, 'foobar', 'myparam'
          server.connections.size.should be == 1
          client.connections.size.should be == 1
          server.halt.join
        end

        it "should be updated when a connection is closed" do
          client.invoke host, 'foobar', 'myparam'
          client.connections.first.unbind
          server.connections.first.unbind
          server.connections.should be_empty
          client.connections.should be_empty
          server.halt.join
        end

        context "with a client already connected" do
          let(:another_client) { TCP.new }

          before(:each) do
            client.invoke host, 'foobar', 'myparam'
          end

          it "should be updated when a new connection is opened" do
            another_client.invoke host, 'foobar', 'myparam'
            server.connections.size.should be == 2
            client.connections.size.should be == 1
            another_client.connections.size.should be == 1
            server.halt.join
          end

          context "with two clients connected" do
            before(:each) do
              client.invoke host, 'foobar', 'myparam'
              another_client.invoke host, 'foobar', 'myparam'
            end

            it "should be updated when a connection is closed" do
              another_client.connections.first.unbind
              server.connections.last.unbind
              server.connections.size.should be == 1
              client.connections.size.should be == 1
              another_client.connections.should be_empty
              server.halt.join
            end
          end
        end
      end

      describe "event handlers" do
        shared_examples "an event handler" do |event|
          it "should be invoked when event is triggered" do
            handler_invoked = false
            server.on(event) { handler_invoked = true }
            client.invoke host, 'foobar', 'myparam'
            server.halt.join
            handler_invoked.should be_truthy
          end

          it "should receive the node" do
            node_received = false
            server.on(event) do |node|
              node_received = true if node.is_a?(RJR::Node)
            end
            client.invoke host, 'foobar', 'myparam'
            server.halt.join
            node_received.should be_truthy
          end

          it "should receive the connection" do
            connection_received = false
            server.on(event) do |_, connection|
              connection_received = true if connection.is_a?(EM::Connection)
            end
            client.invoke host, 'foobar', 'myparam'
            server.halt.join
            connection_received.should be_truthy
          end
        end

        describe "opened event handler" do
          it_behaves_like "an event handler", :opened
        end

        describe "closed event handler" do
          it_behaves_like "an event handler", :closed
        end
      end
    end

    # TODO test callbacks over tcp interface
    # TODO ensure error event handler is invoked
  end
end
