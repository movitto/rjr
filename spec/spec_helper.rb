# simrpc spec system helper
#
# Copyright (C) 2010 Mohammed Morsi <movitto@yahoo.com>
# See LICENSE for the License of this software

require 'rubygems'
require 'spec'
require 'spec/autorun'
require 'spec/interop/test'

dir = File.expand_path(File.dirname(__FILE__) + '/..' )

require dir + '/lib/simrpc'

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

TEST_SCHEMA = 
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
