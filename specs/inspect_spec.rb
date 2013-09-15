require 'rjr/dispatcher'
require 'rjr/inspect'

describe "#select_stats" do
  before(:each) do
    @d = RJR::Dispatcher.new

    @req1   = RJR::Request.new :rjr_node_type => :local, :rjr_method => 'foobar'
    @req1.result = RJR::Result.new :result => true

    @req2   = RJR::Request.new :rjr_node_type => :tcp,   :rjr_method => 'barfoo'
    @req2.result = RJR::Result.new :error_code => 123

    @req3   = RJR::Request.new :rjr_node_type => :amqp,  :rjr_method => 'foobar'
    @req3.result = RJR::Result.new :error_code => 123

    # XXX not prettiest but works for now
    @d.instance_variable_set(:@requests, [@req1, @req2, @req3])
  end

  it "should get all requests" do
    requests = select_stats(@d)
    requests.size.should  == 3
    requests[0].should == @req1
    requests[1].should == @req2
    requests[2].should == @req3
  end

  it "should get all requests for a node" do
    requests = select_stats @d, 'on_node', 'local'
    requests.size.should == 1
    requests.first.should == @req1
  end

  it "should get all requests for a method" do
    requests = select_stats @d, 'for_method', 'foobar'
    requests.size.should == 2
    requests.first.should == @req1
    requests.last.should  == @req3
  end

  it "should get all successfull/failed requests" do
    requests = select_stats @d, 'successful'
    requests.size.should == 1
    requests.first.should == @req1

    requests = select_stats @d, 'failed'
    requests.size.should == 2
    requests.first.should == @req2
    requests.last.should  == @req3
  end

  it "should get dispatcher stats meeting multiple criteria" do
    requests = select_stats @d, 'for_method', 'foobar', 'successful'
    requests.size.should == 1
    requests.first.should == @req1
  end

end
