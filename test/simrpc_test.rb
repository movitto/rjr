# simrpc test suitr
#
# Copyright (C) 2009 Mohammed Morsi <movitto@yahoo.com>
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

require 'rubygems'
require 'test/unit'
require 'mocha'

require File.dirname(__FILE__) + '/../lib/simrpc'
include Simrpc

# test class
class MyClass
  attr_accessor :str_member
  attr_accessor :float_member
  attr_accessor :associated_obj

  attr_accessor :associated_obj_set # boolean indicating if associated_obj is set as it is marked as ignored_null in the schema

  def associated_obj=(value)
    @associated_obj = value
    @associated_obj_set = true
  end

  def initialize(str = '', float = 0.0, associated_obj = nil) # must be able to be initialized w/o any args
    @str_member = str
    @float_member = float
    @associated_obj = associated_obj

    @associated_obj_set = false
  end
end

# simrpc test cases
class SimrpcTest < Test::Unit::TestCase
  def setup
     @test_schema = 
              "<schema>"+
              "  <method name='foo_method'>" +
              "    <param type='int' name='some_int'/>"+
              "    <param type='float' name='floating_point_number'/>"+
              "    <return_value type='str' name='a_string' />" +
              "    <return_value type='obj' name='my_class_instance' associated='MyClass' />" +
              "  </method>"+
              "  <method name='bar_method'>" +
              "    <param type='array' name='byte_array' associated='int'/>"+
              "    <return_value type='int' name='bool_success' />"+
              "  </method>"+
              "  <class name='MyClass'>"+
              "    <member type='str' name='str_member' />" +
              "    <member type='float' name='float_member' />" +
              "    <member type='obj' name='associated_obj' ignore_null='true' />" +
              "  </class>"+
              "</schema>"
  end

  def teardown
  end


  ################## test schema module

  # verifies the schema xml parser produces
  # a valid schema from xml
  def test_parse_schema_xml
     schema_def = Schema::Parser.parse(:schema => @test_schema)

     assert_equal 1, schema_def.classes.size
     assert_equal 2, schema_def.methods.size

     assert_equal "MyClass", schema_def.classes[0].name
     assert_equal 3, schema_def.classes[0].members.size
     assert_equal :str, schema_def.classes[0].members[0].type
     assert_equal 'str_member', schema_def.classes[0].members[0].name
     assert_equal :float, schema_def.classes[0].members[1].type
     assert_equal 'float_member', schema_def.classes[0].members[1].name
     assert_equal :obj, schema_def.classes[0].members[2].type
     assert_equal 'associated_obj', schema_def.classes[0].members[2].name
     assert_equal true, schema_def.classes[0].members[2].ignore_null

     assert_equal "foo_method", schema_def.methods[0].name
     assert_equal 2, schema_def.methods[0].parameters.size
     assert_equal :int, schema_def.methods[0].parameters[0].type
     assert_equal 'some_int', schema_def.methods[0].parameters[0].name
     assert_equal :float, schema_def.methods[0].parameters[1].type
     assert_equal 'floating_point_number', schema_def.methods[0].parameters[1].name
     assert_equal 2, schema_def.methods[0].return_values.size
     assert_equal :str, schema_def.methods[0].return_values[0].type
     assert_equal 'a_string', schema_def.methods[0].return_values[0].name
     assert_equal :obj, schema_def.methods[0].return_values[1].type
     assert_equal 'my_class_instance', schema_def.methods[0].return_values[1].name
     assert_equal :MyClass, schema_def.methods[0].return_values[1].associated
     assert_equal schema_def.classes[0], schema_def.methods[0].return_values[1].associated_class_def(schema_def)

     assert_equal "bar_method", schema_def.methods[1].name
     assert_equal 1, schema_def.methods[1].parameters.size
     assert_equal 1, schema_def.methods[1].return_values.size
     assert_equal :array, schema_def.methods[1].parameters[0].type
     assert_equal 'byte_array', schema_def.methods[1].parameters[0].name
     assert_equal :int, schema_def.methods[1].parameters[0].associated
     assert_equal :int, schema_def.methods[1].return_values[0].type
     assert_equal 'bool_success', schema_def.methods[1].return_values[0].name
  end

  # test the primitives helper functions
  def test_primitive_helpers
      assert Schema::is_primitive?(:int)
      assert Schema::is_primitive?(:float)
      assert Schema::is_primitive?(:str)
      assert !Schema::is_primitive?(:obj)
      assert !Schema::is_primitive?(:array)

      assert_equal "yo", Schema::primitive_from_str(:str, "yo")
      assert_equal 420, Schema::primitive_from_str(:int, "420")
      assert_equal 42.05, Schema::primitive_from_str(:float, "42.05")
  end

  # test converting a data field to / from a string
  def test_data_field_to_from_s
      schema_def = Schema::Parser.parse(:schema => @test_schema)

      data_field = Schema::DataFieldDef.new :name => "foo", :type => :str
      assert_equal "bar", data_field.to_s("bar")
      assert_equal "bar", data_field.from_s("bar")
      data_field.type = :int
      assert_equal "420", data_field.to_s(420)
      assert_equal 420, data_field.from_s("420")
      data_field.type = :float
      assert_equal "15.4", data_field.to_s(15.4)
      assert_equal 15.4, data_field.from_s("15.4")
      data_field.type = :bool
      assert_equal "true", data_field.to_s(true)
      assert_equal true, data_field.from_s("true")
      assert_equal "false", data_field.to_s(false)
      assert_equal false, data_field.from_s("false")

      my_class = MyClass.new("abc", 1.23)
      my_class2 = MyClass.new("def", 4.56)
      my_class_s  = schema_def.classes[0].to_s(my_class, schema_def)
      my_class2_s = schema_def.classes[0].to_s(my_class2, schema_def)
      my_class_o  = schema_def.classes[0].from_s(my_class_s, schema_def)
      my_class2_o = schema_def.classes[0].from_s(my_class2_s, schema_def)

      data_field.type = :obj
      data_field.associated = "MyClass"
      assert_equal my_class_s,
                   data_field.to_s(my_class, schema_def)
      #assert_equal my_class_o,
      #             data_field.from_s(my_class_s, schema_def)
      assert_equal "abc", my_class_o.str_member
      assert_equal 1.23, my_class_o.float_member

      data_field.type = :array
      array_s = data_field.to_s([my_class, my_class2], schema_def)
      assert_equal "0002", array_s[0...4]
      assert_equal "%04d" % my_class_s.size, array_s[4...8]
      end_pos = 8+my_class_s.size
      assert_equal my_class_s, array_s[8...end_pos]
      assert_equal "%04d" % my_class2_s.size, array_s[end_pos...end_pos+4]
      assert_equal my_class2_s, array_s[end_pos+4...end_pos+4+my_class2_s.size]

      array_o = data_field.from_s(array_s, schema_def)
      assert_equal(2, array_o.size)
      #assert_equal my_class_o, array_o[0]
      #assert_equal my_class2_o, array_o[1]
      assert_equal "abc", array_o[0].str_member
      assert_equal "def", array_o[1].str_member
      assert_equal 1.23, array_o[0].float_member
      assert_equal 4.56, array_o[1].float_member

      data_field.associated = :str
      array_s = data_field.to_s(['abc', 'def', 'hijklmnopqrstuvwxyz123456789'])
      assert_equal "0003", array_s[0...4]
      assert_equal "0003", array_s[4...8]
      assert_equal "abc", array_s[8...11]
      assert_equal "0003", array_s[11...15]
      assert_equal "def", array_s[15...18]
      assert_equal "0028", array_s[18...22]
      assert_equal "hijklmnopqrstuvwxyz123456789", array_s[22...50]

      array_o = data_field.from_s(array_s)
      assert_equal(3, array_o.size)
      assert_equal "abc", array_o[0]
      assert_equal "def", array_o[1]
      assert_equal "hijklmnopqrstuvwxyz123456789", array_o[2]

      array_s = data_field.to_s([])
      assert_equal "0000", array_s[0...4]
      array_o = data_field.from_s(array_s)
      assert_equal 0, array_o.size
  end

  # test converting a class to / from a string
  def test_class_to_from_s
      schema_def = Schema::Parser.parse(:schema => @test_schema)
      my_class = MyClass.new('abc', 12.3)
      my_class_s = schema_def.classes[0].to_s(my_class, schema_def)

      assert_equal 19, my_class_s.size
      assert_equal "0003", my_class_s[0...4]
      assert_equal "abc", my_class_s[4...7]
      assert_equal "0004", my_class_s[7...11]
      assert_equal "12.3", my_class_s[11...15]
      assert_equal "0000", my_class_s[15...19]

      my_class_o = schema_def.classes[0].from_s(my_class_s, schema_def)
      assert_equal "abc", my_class_o.str_member
      assert_equal 12.3, my_class_o.float_member
      assert_equal nil, my_class_o.associated_obj
      assert_equal false, my_class_o.associated_obj_set # test ignore_null works

      assert_equal "", schema_def.classes[0].to_s(nil)
      assert_equal nil, schema_def.classes[0].from_s("")

      # test MyClass w/ associated_obj member that has no 'associated' attribute
      my_class = MyClass.new('abc', 12.3, MyClass.new('foo'))
      my_class_s = schema_def.classes[0].to_s(my_class, schema_def)
      assert_equal 48, my_class_s.size
      assert_equal "00290007MyClass0003foo00030.00000", my_class_s[15...48]

      my_class_o = schema_def.classes[0].from_s(my_class_s, schema_def)
      assert_equal "abc", my_class_o.str_member
      assert_equal 12.3, my_class_o.float_member
      assert_equal MyClass, my_class_o.associated_obj.class
      assert_equal "foo", my_class_o.associated_obj.str_member
      assert_equal 0, my_class_o.associated_obj.float_member
      assert_equal true, my_class_o.associated_obj_set # test ignore_null works

      # FIXME test recursion as implemented w/ the converted_classes 
      # parameters to to_s & from_s
  end

  ################## test message module

  # tests format_with_size and parse_from_formatted
  def test_format_parse_data_field
     formatted = Message::Formatter::format_with_size("foobar")
     assert_equal "00000006foobar", formatted
     assert_equal ["foobar", ""], Message::Formatter::parse_from_formatted(formatted)
  end

  # tests Field to_s / from_s
  def test_field_to_from_s
     field = Message::Field.new(:name => "foo", :value => "bar")
     field_s = field.to_s
     assert_equal "00000003foo00000003bar", field_s

     field_o = Message::Field.from_s(field_s)
     assert_equal "foo", field_o.name
     assert_equal "bar", field_o.value
  end

  # tests Header to_s / from_s
  def test_header_to_from_s
     header = Message::Header.new(:target => "footarget")
     header_s = header.to_s
     assert_equal "0000000000000009footarget", header_s

     header_o = Message::Header.from_s(header_s)
     assert_equal "", header.type
     assert_equal "footarget", header.target
  end

  # tests Body to_s / from_s
  def test_body_to_from_s
     body = Message::Body.new
     body.fields.push Message::Field.new(:name => "foo", :value => "bar")
     body.fields.push Message::Field.new(:name => "money", :value => "lotsof")
     body_s = body.to_s
     assert_equal "0000002200000003foo00000003bar0000002700000005money00000006lotsof", body_s

     body_o = Message::Body.from_s(body_s)
     assert_equal 2, body_o.fields.size
     assert_equal "foo", body_o.fields[0].name
     assert_equal "bar", body_o.fields[0].value
     assert_equal "money", body_o.fields[1].name
     assert_equal "lotsof", body_o.fields[1].value
  end

  # tests Message to_s / from_s
  def test_message_to_from_s
     msg = Message::Message.new
     msg.header.type = 'request'
     msg.header.target = 'method'
     msg.body.fields.push Message::Field.new(:name => "foo", :value => "bar")
     msg.body.fields.push Message::Field.new(:name => "money", :value => "lotsof")
     msg_s = msg.to_s

     assert_equal "0000002900000007request00000006method000000650000002200000003foo00000003bar0000002700000005money00000006lotsof", msg_s
     
     msg_o = Message::Message.from_s(msg_s)
     assert_equal 'request', msg_o.header.type
     assert_equal 'method', msg_o.header.target
     assert_equal 2, msg_o.body.fields.size
     assert_equal 'foo', msg_o.body.fields[0].name
     assert_equal 'bar', msg_o.body.fields[0].value
     assert_equal 'money', msg_o.body.fields[1].name
     assert_equal 'lotsof', msg_o.body.fields[1].value
  end
  
  ################## test qpid module

  # ensure that we can connect to the qpid broker
  def test_connect_to_broker
    # TODO test w/ broker/port & specified conf
    qpid = QpidAdapter::Node.new :id => "test1"
    ssn = qpid.instance_variable_get('@ssn')
    id = qpid.instance_variable_get('@node_id')
    assert ! ssn.error?
    assert ! ssn.closed
    assert_equal "test1", id
  end

  # ensure we define a queue and exchange
  def test_establish_exchange_and_queue
     node = QpidAdapter::Node.new :id => "test2"

     exchange = node.instance_variable_get("@exchange")
     assert_equal "test2-exchange", exchange

     queue = node.instance_variable_get("@queue")
     assert_equal "test2-queue", queue

     local_queue = node.instance_variable_get("@local_queue")
     assert_equal "test2-local-queue", local_queue

     routing_key = node.instance_variable_get("@routing_key")
     assert_equal "test2-queue", routing_key

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
  def test_transmit_message
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

  ################## test remaining constructs
  
  # test generating and handling a simrpc message
  def test_generate_and_handle_message
      schema_def = Schema::Parser.parse(:schema => @test_schema)
      mmc = MethodMessageController.new(schema_def)
      msg = mmc.generate('bar_method', [[10,150,20,1130]])

      assert !msg.nil?
      assert_equal 'bar_method', msg.header.target 
      assert_equal 'request', msg.header.type 
      assert_equal 1, msg.body.fields.size 
      assert_equal 'byte_array', msg.body.fields[0].name
      assert_equal '0004000210000315000022000041130', msg.body.fields[0].value

      finished_lock = Semaphore.new(1)
      finished_lock.wait()

      schema_def.methods[1].handler = lambda { |byte_array|
         assert_equal 4, byte_array.size
         assert_equal 10, byte_array[0]
         assert_equal 150, byte_array[1]
         assert_equal 20, byte_array[2]
         assert_equal 1130, byte_array[3]

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
         assert_equal 1, msg.body.fields.size
         assert_equal 'bool_success', msg.body.fields[0].name
         assert_equal 1, msg.body.fields[0].value.to_i
         finished_lock.signal()
      }
      client.send_message("server-queue", msg)
      finished_lock.wait()

      # FIXME test method that doesn't have any return values
  end

  # test common server/client scenario
  def test_node
     server = Node.new(:id => "server3", :schema => @test_schema)
     client = Node.new(:id => "client3", :schema => @test_schema, :destination => "server3")

     server.handle_method("foo_method") { |some_int, floating_point_number|
        assert_equal 10, some_int
        assert_equal 15.4, floating_point_number

        ["work_plz", MyClass.new("foobar", 4.2)] # FIXME have to manually return args in an array
                                                 #       and can't use return 1,2,3,.. shorthand
                                                 #       as currently in ruby, invoking 'return'
                                                 #       from a Proc has undesirable behavior
     }

     a_str, my_class_instance = client.foo_method(10, 15.4)

     assert_equal "work_plz", a_str
     assert_equal "foobar", my_class_instance.str_member
     assert_equal 4.2, my_class_instance.float_member

      # FIXME test method that doesn't have any return values
  end

end
