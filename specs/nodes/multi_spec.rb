require 'rjr/nodes/multi'
require 'rjr/nodes/amqp'
require 'rjr/nodes/web'
require 'rjr/nodes/missing'

if RJR::Nodes::AMQP == RJR::Nodes::Missing ||
   RJR::Nodes::Web  == RJR::Nodes::Missing
puts "Missing AMQP and/or web node dependencies, skipping multi tests"

else
module RJR::Nodes
  describe Multi do
    describe "#listen" do
      it "should listen for messages" do
        invoked1 = invoked2 = false
        rni1 = rni2 = nil
        rnt1 = rnt2 = nil
        p1   = p2   = nil
        amqp  = AMQP.new  :node_id => 'amqp',
                          :broker => 'localhost'
        web   = Web.new   :node_id => 'web',
                          :host => 'localhost', :port => 9876
        multi = Multi.new :node_id => 'multi', 
                          :nodes => [amqp, web]

        multi.dispatcher.handle('method1') { |param|
          rni1 = @rjr_node_id
          rnt1 = @rjr_node_type
          p1   = param
          invoked1 = true
          'retval1'
        }
        multi.dispatcher.handle('method2') { |param|
          rni2 = @rjr_node_id
          rnt2 = @rjr_node_type
          p2   = param
          invoked2 = true
          'retval2'
        }
        multi.listen
        # TODO should wait until we know server is listening

        web_client  = Web.new
        res = web_client.invoke 'http://localhost:9876', 'method2', 'myparam2'
        res.should == 'retval2'
        rni2.should == 'web'
        rnt2.should == :web
        p2.should == 'myparam2'

        amqp_client = AMQP.new :node_id => 'client',
                               :broker => 'localhost'
        res = amqp_client.invoke 'amqp-queue', 'method1', 'myparam1'
        res.should == 'retval1'
        invoked1.should be_truthy
        rni1.should == 'amqp'
        rnt1.should == :amqp
        p1.should == 'myparam1'

        multi.halt.join
      end
    end
  end # describe Multi

end # module RJR::Nodes
end # (!missing)
