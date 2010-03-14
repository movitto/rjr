# simrpc qpid adapter spec
#
# Copyright (c) 2010 Mohammed Morsi <movitto@yahoo.com>
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

require File.dirname(__FILE__) + '/spec_helper'

describe "Simrpc::QpidAdapter" do
  
  ################## test qpid module

  # ensure that we can connect to the qpid broker
  it "should connect to broker" do
    # TODO test w/ broker/port & specified conf
    qpid = QpidAdapter::Node.new :id => "test1"
    ssn = qpid.instance_variable_get('@ssn')
    id = qpid.instance_variable_get('@node_id')
    ssn.error?.should == false
    #ssn.closed.should == false
    id.should == "test1"
  end

  # ensure we define a queue and exchange
  it "should define a queue and exchange" do
     node = QpidAdapter::Node.new :id => "test2"

     exchange = node.instance_variable_get("@exchange")
     exchange.should == "test2-exchange"

     queue = node.instance_variable_get("@queue")
     queue.should == "test2-queue"

     local_queue = node.instance_variable_get("@local_queue")
     local_queue.should == "test2-local-queue"

     routing_key = node.instance_variable_get("@routing_key")
     routing_key.should == "test2-queue"

     ssn = node.instance_variable_get('@ssn')
     assert !ssn.exchange_query("test2-exchange").not_found
     assert !ssn.queue_query("test2-queue").queue.nil?

     # TODO how do I get this:
     #  http://www.redhat.com/docs/en-US/Red_Hat_Enterprise_MRG/1.1/html/python/public/qpid.generator.ControlInvoker_0_10-class.html#exchange_bound_result
     #binding_result = ssn.binding_query("test2-queue")
     #assert !binding_result.exchange_not_found?
     #assert !binding_result.queue_not_found?
     #assert !binding_result.queue_not_matched?
     #assert !binding_result.key_not_found?
  end

  # test sending/receiving a message
  it "should transmit a message" do
    server  = QpidAdapter::Node.new :id => "server1"
    server.async_accept { |node, msg, reply_to|
        assert_equal('test-data', msg)
        node.send_message(reply_to, "test-response")
    }

    finished_lock = Semaphore.new(1)
    finished_lock.wait()

    client = QpidAdapter::Node.new :id => 'client1'
    client.async_accept { |node, msg, reply_to|
       assert_equal("test-response", msg)
       finished_lock.signal()
    }
    client.send_message("server1-queue", "test-data")
    finished_lock.wait()
  end

end
