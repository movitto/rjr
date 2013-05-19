require 'rjr/nodes/amqp'

module RJR::Nodes
  describe AMQP do
    describe "#send_msg" do
      it "should send message to the specified queue"
    end

    describe "#listen" do
      it "should listen for messages" do
        ci = cp = rn = rni = rnt = p = invoked = nil
        node = AMQP.new :node_id => 'server', :broker => 'localhost'
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
        AMQP.new(:node_id => 'client',
                 :broker => 'localhost').invoke 'server-queue',
                                                'test',
                                                'myparam'
        node.halt.join
        invoked.should be_true
        ci.should be_nil
        cp.should be_nil
        rn.should == node
        rni.should == 'server'
        rnt.should == :amqp
        p.should   == 'myparam'
      end
    end

    describe "#invoke" do
      it "should invoke request" do
        server = AMQP.new :node_id => 'server', :broker => 'localhost'
        server.dispatcher.handle('test') do |p|
          'retval'
        end
        server.listen

        client = AMQP.new :node_id => 'client', :broker => 'localhost'
        res = client.invoke 'server-queue', 'test', 'myparam'

        server.halt.join
        res.should == 'retval'
      end
    end

    describe "#notify" do
      it "should send notification" do
        server = AMQP.new :node_id => 'server', :broker => 'localhost'
        server.dispatcher.handle('test') do |p|
          'retval'
        end
        server.listen

        client = AMQP.new :node_id => 'client', :broker => 'localhost'
        res = client.notify 'server-queue', 'test', 'myparam'

        server.halt.join
        res.should == nil
      end
    end

    # TODO test callbacks over amqp interface
    # TODO ensure closed / error event handlers are invoked
  end
end
