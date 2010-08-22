# simrpc node adapter spec
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

describe "Simrpc::Node" do

  it "should generate and handle simrpc message" do
      schema_def = Schema::Parser.parse(:schema => TEST_SCHEMA)
      mmc = MethodMessageController.new(schema_def)
      msg = mmc.generate('bar_method', [[10,150,20,1130]])

      msg.should_not be_nil
      msg.header.target.should == 'bar_method'
      msg.header.type.should == 'request'
      msg.body.fields.size.should == 1
      msg.body.fields[0].name.should == 'byte_array'
      msg.body.fields[0].value.should == '0004000210000315000022000041130'

      finished_lock = Semaphore.new(1)
      finished_lock.wait()

      schema_def.methods[1].handler = lambda { |byte_array|
         byte_array.size.should == 4
         byte_array[0].should == 10
         byte_array[1].should == 150
         byte_array[2].should == 20
         byte_array[3].should == 1130

         x = 0
         byte_array.each { |b| x += b }
         return x > 300 ? 1 : 0
      }

      server  = QpidAdapter::Node.new :id => "server"
      server.async_accept { |node, msg, reply_to|
        mmc.message_received(node, msg, reply_to)
      }

      client = QpidAdapter::Node.new :id => 'client'
      client.async_accept { |node, msg, reply_to|
         msg = Message::Message.from_s(msg)
         msg.body.fields.size.should == 1
         msg.body.fields[0].name.should == 'bool_success'
         msg.body.fields[0].value.to_i.should == 1
         finished_lock.signal()
      }
      client.send_message("server-queue", msg)
      finished_lock.wait()

      server.terminate
      client.terminate

      # FIXME test method that doesn't have any return values
  end

  it "should handle default values" do
      schema_def = Schema::Parser.parse(:schema => TEST_SCHEMA)
      mmc = MethodMessageController.new(schema_def)
      msg = mmc.generate('foo_method', [2])

      finished_lock = Semaphore.new(1)
      finished_lock.wait()

      schema_def.methods[0].handler = lambda { |some_int, floating_point_number|
        some_int.to_i.should == 2
        floating_point_number.to_f.should == 5.6 # test default value
        return "yo", MyClass.new
      }

      server  = QpidAdapter::Node.new :id => "server"
      server.async_accept { |node, msg, reply_to|
        mmc.message_received(node, msg, reply_to)
      }

      client = QpidAdapter::Node.new :id => 'client'
      client.async_accept { |node, msg, reply_to|
         #msg = Message::Message.from_s(msg)
         finished_lock.signal()
      }
      client.send_message("server-queue", msg)
      finished_lock.wait()

      server.terminate
      client.terminate
  end

  it "it should run properly" do
     server = Node.new(:id => "server3", :schema => TEST_SCHEMA)
     client = Node.new(:id => "client3", :schema => TEST_SCHEMA, :destination => "server3")

     server.handle_method("foo_method") { |some_int, floating_point_number|
        some_int.should == 10
        floating_point_number.should == 15.4

        ["work_plz", MyClass.new("foobar", 4.2)] # FIXME have to manually return args in an array
                                                 #       and can't use return 1,2,3,.. shorthand
                                                 #       as currently in ruby, invoking 'return'
                                                 #       from a Proc has undesirable behavior
     }

     a_str, my_class_instance = client.foo_method(10, 15.4)

     a_str.should == "work_plz"
     my_class_instance.str_member.should == "foobar"
     my_class_instance.float_member.should == 4.2

      # FIXME test method that doesn't have any return values

      client.terminate
      server.terminate
  end

end
