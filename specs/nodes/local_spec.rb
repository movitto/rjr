require 'rjr/nodes/local'

module RJR::Nodes
  describe Local do
    describe "#send_msg" do
      it "should dispatch local notification"
    end

    describe "#invoke" do
      it "should dispatch local request" do
        invoked = rn = rni = rnt = p = nil
        node = Local.new :node_id => 'aaa'
        node.dispatcher.handle('foobar') { |param|
          rn  = @rjr_node
          rni = @rjr_node_id
          rnt = @rjr_node_type
          p   = param
          invoked = true
          'retval'
        }

        res = node.invoke 'foobar', 'myparam'

        invoked.should == true
        res.should == 'retval'
        rn.should  == node
        rni.should == 'aaa'
        rnt.should == :local
        p.should   == 'myparam'
      end
    end

    describe "#notify" do
      it "should dispatch local notification" do
        # notify will most likely return before
        # handler is executed (in seperate thread), wait
        m,c = Mutex.new, ConditionVariable.new

        invoked = nil
        node = Local.new :node_id => 'aaa'
        node.dispatcher.handle('foobar') { |param|
          invoked = true
          m.synchronize { c.signal }
          'retval'
        }

        res = node.notify 'foobar', 'myparam'
        res.should == nil
        m.synchronize { c.wait m, 0.1 } unless invoked
        invoked.should == true
      end
    end

    it "should invoke callbacks" do
      node = Local.new
      cbp = nil
      foobar_invoked = false
      callback_invoked = false
      node.dispatcher.handle('foobar') {
        foobar_invoked = true
        @rjr_callback.notify('callback', 'cp')
      }
      node.dispatcher.handle('callback') { |param|
        callback_invoked = true
        cbp = param
      }

      node.invoke 'foobar', 'myparam'
      foobar_invoked.should be_true
      callback_invoked.should be_true
      cbp.should == 'cp'
    end

    # TODO make sure local parameters are not modified if altered
    # on remote end of invoke/notify

  end # desribe Local
end  # module RJR::Nodes
