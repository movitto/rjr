require 'rjr/dispatcher'
require 'rjr/node'

module RJR
  describe Node do
    describe "::persistent?" do
      context "PERSISTENT_NODE is defined and true" do
        it "returns true" do
          new_node = Class.new(Node)
          new_node.const_set(:PERSISTENT_NODE, true)
          new_node.should be_persistent
        end
      end

      context "PERSISTENT_NODE is not defined" do
        it "returns false" do
          Node.should_not be_persistent
        end
      end

      context "PERSISTENT_NODE returns false" do
        it "returns false" do
          new_node = Class.new(Node)
          new_node.const_set(:PERSISTENT_NODE, false)
          new_node.should_not be_persistent
        end
      end
    end

    describe "#persistent?" do
      context "instance of a persistent node" do
        it "returns true" do
          new_node = Class.new(Node)
          new_node.const_set(:PERSISTENT_NODE, true)
          new_node.new.should be_persistent
        end
      end

      context "not an instance of a persistent node" do
        it "returns false" do
          Node.new.should_not be_persistent
        end
      end
    end

    describe "::indirect?" do
      context "INDIRECT_NODE defined and true" do
        it "returns true" do
          new_node = Class.new(Node)
          new_node.const_set(:INDIRECT_NODE, true)
          new_node.should be_indirect
        end
      end

      context "INDIRECT_NODE not defined" do
        it "returns false" do
          Node.should_not be_indirect
        end
      end

      context "INDIRECT_NODE false" do
        it "returns false" do
          new_node = Class.new(Node)
          new_node.const_set(:INDIRECT_NODE, false)
          new_node.should_not be_indirect
        end
      end
    end

    describe "#indirect?" do
      context "node is indirect" do
        it "returns true" do
          new_node = Class.new(Node)
          new_node.const_set(:INDIRECT_NODE, true)
          new_node.new.should be_indirect
        end
      end

      context "node is direct" do
        it "returns false" do
          Node.new.should_not be_indirect
        end
      end
    end

    describe "#node_type" do
      it "returns NODE_TYPE" do
        new_node = Class.new(Node)
        new_node.const_set(:RJR_NODE_TYPE, 'nt')
        new_node.new.node_type.should == 'nt'
      end
    end

    describe "#initialize" do
      it "sets node id" do
        node = Node.new :node_id => 'node1'
        node.node_id.should == 'node1'
      end

      it "sets dispatcher" do
        dispatcher = Dispatcher.new
        node = Node.new :dispatcher => dispatcher
        node.dispatcher.should == dispatcher
      end

      context "dispatcher not specified" do
        it "initializes dispatcher" do
          Node.new.dispatcher.should be_an_instance_of(Dispatcher)
        end
      end

      it "sets message headers" do
        headers = {:header1 => :val}
        node = Node.new :headers => headers
        node.message_headers.should == headers
      end

      context "headers not specified" do
        it "initializes blank headers" do
          Node.new.message_headers.should == {}
        end
      end

      it "initializes shared thread pool" do
        Node.new
        Node.tp.should_not be_nil
        orig = Node.tp

        Node.new.tp.should == orig
        Node.tp.should == orig
      end

      it "initializes shared em adapter" do
        Node.new
        Node.em.should_not be_nil
        orig = Node.em

        Node.new.em.should == orig
        Node.em.should == orig
      end

      it "starts thread pool" do
        tp = ThreadPool.new
        Node.should_receive(:tp).and_return(tp)
        tp.should_receive(:start)
        Node.new
      end

      it "starts em adapter" do
        em = EMAdapter.new
        Node.should_receive(:em).and_return(em)
        em.should_receive(:start)
        Node.new
      end
    end

    describe "#join" do
      it "joins thread pool & em adapter and returns self" do
        Node.tp.should_receive(:join)
        Node.em.should_receive(:join)
        n = Node.new
        n.join.should == n
      end
    end

    describe "#halt" do
      it "stops thread pool & em adatper and returns self" do
        Node.tp.should_receive(:stop)
        Node.em.should_receive(:stop_event_loop)
        n = Node.new
        n.halt.should == n
      end
    end

    describe "#clear_event_handlers" do
      it "resets connection event handlers" do
        n = Node.new
        n.on(:error) {}
        n.clear_event_handlers
        n.connection_event_handlers.should == {:closed => [], :error => []}
      end
    end

    describe "#on" do
      it "registers new connection event handler" do
        bl = proc{}
        n = Node.new
        n.on(:error, &bl)
        n.connection_event_handlers.should == {:closed => [], :error => [bl]}
      end
    end

    describe "#connection_event" do
      it "invokes event handlers" do
        bl = proc{}
        n = Node.new
        n.on(:error, &bl)
        bl.should_receive(:call).with(n)
        n.send :connection_event, :error
      end
    end

    describe "#client_for" do
      context "node is indirect" do
        it "returns nil" do
          n = Node.new
          n.should_receive(:indirect?).and_return(true)
          n.send(:client_for, 'whatever').should == [nil, nil]
        end
      end

      context "node is local" do
        it "returns nil" do
          n = Node.new
          n.should_receive(:node_type).and_return(:local)
          n.send(:client_for, 'whatever').should == [nil, nil]
        end
      end

      it "extracts & returns client ip and port from socket connection" do
        n = Node.new
        n.should_receive(:node_type).and_return(:tcp)

        c = Object.new
        c.should_receive(:get_peername).and_return('peername')
        expected = ['127.0.0.1', 5000]
        Socket.should_receive(:unpack_sockaddr_in).
          with('peername').and_return(expected)
        n.send(:client_for, c).should == expected
      end

      context "error during ip/port extraction" do
        it "returns nil" do
          n = Node.new
          n.should_receive(:node_type).and_return(:tcp)

          c = Object.new
          c.should_receive(:get_peername).and_raise(Exception)
          n.send(:client_for, c).should == [nil, nil]
        end
      end
    end

    describe "#handle_message" do
      context "request message" do
        it "handles request via thread pool" do
          connection = Object.new
          request = Messages::Request.new  :id => 1, :method => 'foo'
          request_str = request.to_s

          node = Node.new
          node.tp.should_receive(:<<) { |job|
            job.should be_an_instance_of(ThreadPoolJob)
            job.exec Mutex.new
          }

          node.should_receive(:handle_request).with(request_str, false, connection)
          node.send :handle_message, request_str, connection
        end
      end

      context "notification message" do
        it "handles notification via thread pool" do
          connection = Object.new
          notification = Messages::Notification.new  :method => 'foo'
          notification_str = notification.to_s

          node = Node.new
          node.tp.should_receive(:<<) { |job|
            job.should be_an_instance_of(ThreadPoolJob)
            job.exec Mutex.new
          }

          node.should_receive(:handle_request).
            with(notification_str, true, connection)
          node.send :handle_message, notification_str, connection
        end
      end

      context "response message" do
        it "handles response" do
          response = Messages::Response.new :result => Result.new
          response_str = response.to_s

          node = Node.new
          node.should_receive(:handle_response).with(response_str)
          node.send :handle_message, response_str
        end
      end

      context "anything else" do
        it "does nothing" do
          node = Node.new
          node.tp.should_not_receive(:<<)
          node.should_not_receive(:handle_request)
          node.should_not_receive(:handle_response)
          node.send :handle_message, "{}"
        end
      end
    end

    describe "#handle_request" do
      before(:each) do
         notification =
           Messages::Notification.new :method  => 'rjr_method1',
                                      :args    => ['method', 'args'],
                                      :headers => {'msg' => 'headers'}
        @notification = notification.to_s
        @node = Node.new
      end

      it "invokes dispatcher.dispatch" do
        @node.dispatcher.should_receive(:dispatch)
        @node.send :handle_request, @notification, true
      end

      describe "dispatcher.dispatch args" do
        it "includes :rjr_method => msg.jr_method" do
          @node.dispatcher.should_receive(:dispatch) { |args|
            args[:rjr_method].should == 'rjr_method1'
          }
          @node.send :handle_request, @notification, true
        end

        it "includes :rjr_method_args => msg.jr_args" do
          @node.dispatcher.should_receive(:dispatch) { |args|
            args[:rjr_method_args].should == ['method', 'args']
          }
          @node.send :handle_request, @notification, true
        end

        it "includes :rjr_headers => msg.headers" do
          @node.dispatcher.should_receive(:dispatch) { |args|
            args[:rjr_headers].should == {'msg' => 'headers'}
          }
          @node.send :handle_request, @notification, true
        end

        it "includes :rjr_client_ip => extracted client ip" do
          connection = Object.new
          @node.should_receive(:client_for).with(connection).
            and_return([9999, '127.0.0.1'])
          @node.dispatcher.should_receive(:dispatch) { |args|
            args[:rjr_client_ip].should == '127.0.0.1'
          }
          @node.send :handle_request, @notification, true, connection
        end

        it "includes :rjr_client_port => extracted client port" do
          connection = Object.new
          @node.should_receive(:client_for).with(connection).
            and_return([9999, '127.0.0.1'])
          @node.dispatcher.should_receive(:dispatch) { |args|
            args[:rjr_client_port].should == 9999
          }
          @node.send :handle_request, @notification, true, connection
        end

        it "includes :rjr_node => self" do
          @node.dispatcher.should_receive(:dispatch) { |args|
            args[:rjr_node].should == @node
          }
          @node.send :handle_request, @notification, true
        end

        it "includes :rjr_node_id => self.node_id" do
          @node.should_receive(:node_id).and_return('node_id')
          @node.dispatcher.should_receive(:dispatch) { |args|
            args[:rjr_node_id].should == 'node_id'
          }
          @node.send :handle_request, @notification, true
        end

        it "includes :rjr_node_type => self.node_type" do
          @node.should_receive(:node_type).at_least(:once).and_return(:nt)
          @node.dispatcher.should_receive(:dispatch) { |args|
            args[:rjr_node_type].should == :nt
          }
          @node.send :handle_request, @notification, true
        end

        it "includes :rjr_callback => constructed node callback" do
          @node.dispatcher.should_receive(:dispatch) { |args|
            args[:rjr_callback].should be_an_instance_of(NodeCallback)
          }
          @node.send :handle_request, @notification, true
        end

        describe "specified node callback" do
          it "has a handle to the node" do
            @node.dispatcher.should_receive(:dispatch) { |args|
              args[:rjr_callback].node.should == @node
            }
            @node.send :handle_request, @notification, true
          end

          it "has a handle to the connection" do
            connection = Object.new
            @node.dispatcher.should_receive(:dispatch) { |args|
              args[:rjr_callback].connection.should == connection
            }
            @node.send :handle_request, @notification, true, connection
          end
        end
      end

      context "handling request / not a notification" do
        before(:each) do
           request = Messages::Request.new :method  => 'method1',
                                           :args    => ['method', 'args'],
                                           :headers => {'msg' => 'headers'}
          @request = request.to_s

          result = Result.new
          @expected = Messages::Response.new :result  => result,
                                             :headers => {'msg' => 'headers'},
                                             :id      => request.msg_id

          # stub out dispatch
          @node.dispatcher.should_receive(:dispatch).and_return(result)
        end

        it "sends response msg string via connection" do
          connection = Object.new
          @node.should_receive(:send_msg) { |response,econnection|
            response.should == @expected.to_s
            econnection.should == connection
          }
          @node.send :handle_request, @request, false, connection
        end

        it "returns response" do
          @node.should_receive(:send_msg) # stub out
          response = @node.send(:handle_request, @request, false)
          response.should be_an_instance_of(Messages::Response)
          response.to_s.should == @expected.to_s
        end
      end

      it "returns nil" do
        @node.send(:handle_request, @notification, true).should be_nil
      end
    end

    describe "#handle_response" do
      before(:each) do
        @node = Node.new

        @result = Result.new :result => 42
         response = Messages::Response.new :id => 'msg1', :result => @result
        @response = response.to_s
      end

      it "invokes dispatcher.handle_response with response result" do
        @node.dispatcher.should_receive(:handle_response) { |r|
          r.should be_an_instance_of(Result)
          r.result.should == 42
        }
        @node.send :handle_response, @response
      end

      it "adds response msg_id and result to response queue" do
        @node.send :handle_response, @response
        responses = @node.instance_variable_get(:@responses)
        responses.size.should == 1
        responses.first[0].should == 'msg1'
        responses.first[1].should == 42
      end

      context "response contains error" do
        it "adds response error to response queue" do
          @node.dispatcher.should_receive(:handle_response).and_raise(Exception)
          @node.send :handle_response, @response
          responses = @node.instance_variable_get(:@responses)
          responses.first[2].should be_an_instance_of(Exception)
        end
      end

      it "signals response cv" do
        @node.instance_variable_get(:@response_cv).should_receive(:broadcast)
        @node.send :handle_response, @response
      end
    end

    describe "#wait_for_result" do
      before(:each) do
        @node = Node.new
        @msg  = Messages::Request.new :method => 'method1', :args => []
        @response = [@msg.msg_id, 42]
      end

      context "response in response queue" do
        before(:each) do
          @node.instance_variable_set(:@responses, [@response])
        end

        it "deletes response from queue" do
          @node.send :wait_for_result, @msg
          @node.instance_variable_get(:@responses).should be_empty
        end

        it "returns response" do
          @node.send(:wait_for_result, @msg).should == @response
        end
      end

      context "response not in response queue" do
        it "waits on response cv" do
          node = Node.new
          node.instance_variable_get(:@response_cv).stub(:wait) {
            node.instance_variable_set(:@responses, [@response])
          }
          node.instance_variable_get(:@response_cv).should_receive(:wait).once
          node.send(:wait_for_result, @msg)
        end
      end
    end
  end # describe Node
end # module RJR
