require 'rjr/inspect'

describe 'rjr/inspect.rb' do
  describe "select_stats" do
    before(:each) do
      RJR::DispatcherStat.reset

      req1   = RJR::Request.new :rjr_node_type => :local, :method => 'foobar'
      req2   = RJR::Request.new :rjr_node_type => :tcp,   :method => 'barfoo'
      req3   = RJR::Request.new :rjr_node_type => :amqp,  :method => 'foobar'
      res1   = RJR::Result.new :result => true
      res2   = RJR::Result.new :error_code => 123
      res3   = RJR::Result.new :error_code => 123

      @stat1 = RJR::DispatcherStat.new req1, res1
      @stat2 = RJR::DispatcherStat.new req2, res2
      @stat3 = RJR::DispatcherStat.new req3, res3
      RJR::DispatcherStat << @stat1 << @stat2 << @stat3
    end

    it "should get all dispatcherstats" do
      stats = select_stats
      stats.size.should == 3
      stats.first.should == @stat1
      stats[1].should  == @stat2
      stats.last.should  == @stat3
    end

    it "should get all dispatcherstats for a node" do
      stats = select_stats 'on_node', 'local'
      stats.size.should == 1
      stats.first.should == @stat1
    end

    it "should get all dispatcherstats for a method" do
      stats = select_stats 'for_method', 'foobar'
      stats.size.should == 2
      stats.first.should == @stat1
      stats.last.should  == @stat3
    end

    it "should get all successfull/failed dispatcherstats" do
      stats = select_stats 'successful'
      stats.size.should == 1
      stats.first.should == @stat1

      stats = select_stats 'failed'
      stats.size.should == 2
      stats.first.should == @stat2
      stats.last.should  == @stat3
    end

    it "should get dispatcher stats meeting multiple criteria" do
      stats = select_stats 'for_method', 'foobar', 'successful'
      stats.size.should == 1
      stats.first.should == @stat1
    end
  end

end
