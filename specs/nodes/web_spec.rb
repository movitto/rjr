require 'rjr/nodes/web'
require 'rjr/nodes/missing'

if RJR::Nodes::Web == RJR::Nodes::Missing
puts "Missing Web node dependencies, skipping web tests"

else
module RJR::Nodes
  describe Web do
    describe "#send_msg" do
      it "should send response using the specified connection"
    end

    describe "#listen" do
      it "should listen for messages" do
        ci = cp = rn = rni = rnt = p = invoked = nil
        node = Web.new :node_id => 'www', :host => '127.0.0.1', :port => 9678
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
        Web.new.invoke 'http://127.0.0.1:9678', 'test', 'myparam'
        node.halt.join
        invoked.should be_truthy
        ci.should == '127.0.0.1'
        #cp.should
        rn.should == node
        rni.should == 'www'
        rnt.should == :web
        p.should   == 'myparam'
      end
    end

    describe "#invoke" do
      it "should invoke request" do
        server = Web.new :node_id => 'www', :host => '127.0.0.1', :port => 9678
        server.dispatcher.handle('test') do |p|
          'retval'
        end
        server.listen

        client = Web.new
        res = client.invoke 'http://127.0.0.1:9678', 'test', 'myparam'

        server.halt.join
        res.should == 'retval'
      end
    end

    describe "#notify" do
      it "should send notification" do
        server = Web.new :node_id => 'www', :host => '127.0.0.1', :port => 9678
        server.dispatcher.handle('test') do |p|
          'retval'
        end
        server.listen

        client = Web.new
        res = client.notify 'http://127.0.0.1:9678', 'test', 'myparam'

        server.halt.join
        res.should == nil
      end
    end

    # TODO ensure closed / error event handlers are invoked
  end # describe Web
end # module RJR::Nodes
end # (!missing)
