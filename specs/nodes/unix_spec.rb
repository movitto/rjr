require 'rjr/nodes/unix'

module RJR::Nodes
  describe Unix do
    describe "#send_msg" do
      it "should send message using the specifed connection"
    end

    describe "#listen" do
      it "should listen for messages" do
        rn = rni = rnt = p = invoked = nil
        server  = Unix.new :node_id => 'unix',
                           :socketname => './test.sock'
        server.dispatcher.handle('foobar') { |param|
          rn  = @rjr_node
          rni = @rjr_node_id
          rnt = @rjr_node_type
          p   = param
          invoked = true
        }
        server.listen

        # issue request
        Unix.new.invoke './test.sock', 'foobar', 'myparam'
        server.halt.join
        rn.should == server
        rni.should == 'unix'
        rnt.should == :unix
        p.should == 'myparam'
        invoked.should == true
      end
    end

    describe "#invoke" do
      it "should invoke request" do
        server  = Unix.new :node_id => 'unix',
                           :socketname => './test.sock'
        server.dispatcher.handle('foobar') { |param|
          'retval'
        }
        server.listen

        client = Unix.new
        res = client.invoke './test.sock', 'foobar', 'myparam'
        server.halt.join
        res.should == 'retval'
      end
    end

    describe "#notify" do
      it "should send notification" do
        server  = Unix.new :node_id => 'unix',
                           :socketname => './test.sock'
        server.dispatcher.handle('foobar') { |param|
          'retval'
        }
        server.listen

        client = Unix.new
        res = client.notify './test.sock', 'foobar', 'myparam'
        server.halt.join
        res.should == nil
      end
    end

    # TODO test callbacks over unix interface
    # TODO ensure closed / error event handlers are invoked
  end
end


