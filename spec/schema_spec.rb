# simrpc schema spec
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

describe "Simrpc::Schema" do

  it "should correctly parse a simrpc schema" do
     schema_def = Schema::Parser.parse(:schema => TEST_SCHEMA)

     schema_def.classes.size.should == 1
     schema_def.methods.size.should == 2

     schema_def.classes[0].name.should == "MyClass"
     schema_def.classes[0].members.size.should == 3
     schema_def.classes[0].members[0].type.should == :str
     schema_def.classes[0].members[0].name.should == 'str_member'
     schema_def.classes[0].members[1].type.should == :float
     schema_def.classes[0].members[1].name.should == 'float_member'
     schema_def.classes[0].members[2].type.should == :obj
     schema_def.classes[0].members[2].name.should == 'associated_obj'
     schema_def.classes[0].members[2].ignore_null.should == true

     schema_def.methods[0].name.should == "foo_method"
     schema_def.methods[0].parameters.size.should == 2
     schema_def.methods[0].parameters[0].type.should == :int
     schema_def.methods[0].parameters[0].name.should == 'some_int'
     schema_def.methods[0].parameters[1].type.should == :float
     schema_def.methods[0].parameters[1].name.should == 'floating_point_number'
     schema_def.methods[0].return_values.size.should == 2
     schema_def.methods[0].return_values[0].type.should == :str
     schema_def.methods[0].return_values[0].name.should == 'a_string'
     schema_def.methods[0].return_values[1].type.should == :obj
     schema_def.methods[0].return_values[1].name.should == 'my_class_instance'
     schema_def.methods[0].return_values[1].associated.should == :MyClass
     schema_def.methods[0].return_values[1].associated_class_def(schema_def).should == schema_def.classes[0]

     schema_def.methods[1].name.should == "bar_method"
     schema_def.methods[1].parameters.size.should == 1
     schema_def.methods[1].return_values.size.should == 1
     schema_def.methods[1].parameters[0].type.should == :array
     schema_def.methods[1].parameters[0].name.should == 'byte_array'
     schema_def.methods[1].parameters[0].associated.should == :int
     schema_def.methods[1].return_values[0].type.should == :int
     schema_def.methods[1].return_values[0].name.should == 'bool_success'
  end

  it "should correct parse class" do
      schema_def = Schema::Parser.parse(:schema => 
         "<schema><class name='Base'></class><class name='Derived' inherits='Base' /></schema>")

     schema_def.classes.size.should == 2
     schema_def.classes[0].name.should == "Base"
     schema_def.classes[0].inherits.should == nil
     schema_def.classes[1].name.should == "Derived"
     schema_def.classes[1].inherits.should == "Base"
  end

  it "should correctly identify primitives" do
      Schema::is_primitive?(:int).should == true
      Schema::is_primitive?(:float).should == true
      Schema::is_primitive?(:str).should == true
      !Schema::is_primitive?(:obj).should == true
      !Schema::is_primitive?(:array).should == true

      Schema::primitive_from_str(:str, "yo").should == "yo"
      Schema::primitive_from_str(:int, "420").should == 420
      Schema::primitive_from_str(:float, "42.05").should == 42.05
  end

  it "should convert a data field to / from a string" do
      schema_def = Schema::Parser.parse(:schema => TEST_SCHEMA)

      data_field = Schema::DataFieldDef.new :name => "foo", :type => :str
      data_field.to_s("bar").should == "bar"
      data_field.from_s("bar").should == "bar"
      data_field.type = :int
      data_field.to_s(420).should == "420"
      data_field.from_s("420").should == 420
      data_field.type = :float
      data_field.to_s(15.4).should == "15.4"
      data_field.from_s("15.4").should == 15.4
      data_field.type = :bool
      data_field.to_s(true).should == "true"
      data_field.from_s("true").should == true
      data_field.to_s(false).should == "false"
      data_field.from_s("false").should == false

      my_class = MyClass.new("abc", 1.23)
      my_class2 = MyClass.new("def", 4.56)
      my_class_s  = schema_def.classes[0].to_s(my_class, schema_def)
      my_class2_s = schema_def.classes[0].to_s(my_class2, schema_def)
      my_class_o  = schema_def.classes[0].from_s(my_class_s, schema_def)
      my_class2_o = schema_def.classes[0].from_s(my_class2_s, schema_def)

      data_field.type = :obj
      data_field.associated = "MyClass"
      data_field.to_s(my_class, schema_def).should == my_class_s
      #assert_equal my_class_o,
      #             data_field.from_s(my_class_s, schema_def)
      my_class_o.str_member.should == "abc"
      my_class_o.float_member.should == 1.23

      data_field.type = :array
      array_s = data_field.to_s([my_class, my_class2], schema_def)
      array_s[0...4].should == "0002"
      array_s[4...8].should == "%04d" % my_class_s.size
      end_pos = 8+my_class_s.size
      array_s[8...end_pos].should == my_class_s
      array_s[end_pos...end_pos+4].should == "%04d" % my_class2_s.size
      array_s[end_pos+4...end_pos+4+my_class2_s.size].should == my_class2_s

      array_o = data_field.from_s(array_s, schema_def)
      array_o.size.should == 2
      #assert_equal my_class_o, array_o[0]
      #assert_equal my_class2_o, array_o[1]
      array_o[0].str_member.should == "abc"
      array_o[1].str_member.should == "def"
      array_o[0].float_member.should == 1.23
      array_o[1].float_member.should == 4.56

      data_field.associated = :str
      array_s = data_field.to_s(['abc', 'def', 'hijklmnopqrstuvwxyz123456789'])
      array_s[0...4].should == "0003"
      array_s[4...8].should == "0003"
      array_s[8...11].should == "abc"
      array_s[11...15].should == "0003"
      array_s[15...18].should == "def"
      array_s[18...22].should == "0028"
      array_s[22...50].should == "hijklmnopqrstuvwxyz123456789"

      array_o = data_field.from_s(array_s)
      array_o.size.should == 3
      array_o[0].should == "abc"
      array_o[1].should == "def"
      array_o[2].should == "hijklmnopqrstuvwxyz123456789"

      array_s = data_field.to_s([])
      array_s[0...4].should == "0000"
      array_o = data_field.from_s(array_s)
      array_o.size.should == 0
  end

  it "should raise an error if a field refers to an invalid class" do
     schema_def = Schema::Parser.parse(:schema =>
         "<schema>" + 
           "<class name='SchemaTestSuper'>"+ 
             "<member type='obj' name='super_attr' />" +
           "</class>" + 
         "</schema>")

     lambda { 
       schema_def.classes[0].members[0].to_s(SchemaTestBase.new, schema_def) # try converting a class not defined in schema to_s
     }.should raise_error(InvalidSchemaClass, "cannot find SchemaTestBase in schema")

     lambda { 
       schema_def.classes[0].members[0].from_s("0014SchemaTestBase", schema_def)
     }.should raise_error(InvalidSchemaClass, "cannot find SchemaTestBase in schema")


     schema_def = Schema::Parser.parse(:schema =>
         "<schema>" + 
           "<class name='SchemaTestSuper'>"+ 
             "<member type='obj' associated='SchemaTestDerived' name='super_attr' />" + # associate w/ class not defined in schema
           "</class>" + 
         "</schema>")

     lambda { 
       schema_def.classes[0].members[0].to_s(SchemaTestDerived.new, schema_def)
     }.should raise_error(InvalidSchemaClass, "cannot find SchemaTestDerived in schema")

     lambda { 
       schema_def.classes[0].members[0].from_s("0017SchemaTestDerived", schema_def)
     }.should raise_error(InvalidSchemaClass, "cannot find SchemaTestDerived in schema")
  end

  it "should convert a class to / from a string" do
      schema_def = Schema::Parser.parse(:schema => TEST_SCHEMA)
      my_class = MyClass.new('abc', 12.3)
      my_class_s = schema_def.classes[0].to_s(my_class, schema_def)

      my_class_s.size.should == 20
      my_class_s[0].chr.should == "I"        # object defined here, not refrence to elsewhere
      my_class_s[1...5].should == "0003"     # length of the first member
      my_class_s[5...8].should == "abc"      # first member in string format
      my_class_s[8...12].should == "0004"    # length of second member
      my_class_s[12...16].should == "12.3"   # second member in string format
      my_class_s[16...20].should == "0000"   # length of last class member (since we're not setting in this case, 0)

      my_class_o = schema_def.classes[0].from_s(my_class_s, schema_def)
      my_class_o.class.should == MyClass
      my_class_o.str_member.should == "abc"
      my_class_o.float_member.should == 12.3
      my_class_o.associated_obj.should == nil
      my_class_o.associated_obj_set.should == false # test ignore_null works

      schema_def.classes[0].to_s(nil).should == "I"
      schema_def.classes[0].from_s("I").should == nil

      # test MyClass w/ associated_obj member that has no 'associated' attribute
      my_class = MyClass.new('abc', 12.3, MyClass.new('foo'))
      my_class_s = schema_def.classes[0].to_s(my_class, schema_def)
      my_class_s.size.should == 50
      my_class_s.should == "I" + "0003" + "abc" + "0004" + "12.3" + "0030" + "0007" + "MyClass" + "I" + "0003" + "foo" + "0003" + "0.0" + "0000"

      my_class_o = schema_def.classes[0].from_s(my_class_s, schema_def)
      my_class_o.str_member.should == "abc"
      my_class_o.float_member.should == 12.3
      my_class_o.associated_obj.class.should == MyClass
      my_class_o.associated_obj.str_member.should == "foo"
      my_class_o.associated_obj.float_member.should == 0
      my_class_o.associated_obj_set.should == true # test ignore_null works

      # FIXME test recursion as implemented w/ the converted_classes 
      # parameters to to_s & from_s
  end

  it "should convert an inherited class to / from a string" do
      schema_def = Schema::Parser.parse(:schema => 
         "<schema>" + 
           "<class name='SchemaTestSuper'>"+ 
             "<member type='str' name='super_attr' />" +
           "</class>" +
           "<class name='SchemaTestBase' inherits='SchemaTestSuper' >"+ 
             "<member type='str' name='base_attr' />" +
           "</class>" +
           "<class name='SchemaTestDerived' inherits='SchemaTestBase'>" +
             "<member type='str' name='derived_attr' />" +
           "</class>" +
         "</schema>")

      derived = SchemaTestDerived.new
      derived.derived_attr = "foo"
      derived.base_attr = "bar"
      derived.super_attr = "superman"

      ds = schema_def.classes[2].to_s(derived, schema_def)
      ds.should == "I" + "0003" + "foo" + "0003" + "bar" + "0008" + "superman"

      dso = schema_def.classes[2].from_s(ds, schema_def)
      dso.derived_attr.should == "foo"
      dso.base_attr.should == "bar"
      dso.super_attr.should == "superman"
  end

  it "should convert a class w/ generic object attribute to / from string" do
     schema_def = Schema::Parser.parse(:schema =>
         "<schema>" + 
           "<class name='SchemaTestSuper'>"+ 
             "<member type='obj' name='super_attr' />" +
             "<member type='str' name='another_attr' />" +
           "</class>" + 
         "</schema>")

     sup1 = SchemaTestSuper.new
     sup2 = SchemaTestSuper.new
     sup2.another_attr = "foobar"
     sup1.super_attr = sup2

     ss = schema_def.classes[0].to_s(sup1, schema_def)
     ss.should == "I" + "0034" + "0015" + "SchemaTestSuper" + "I" + "0000" + "0006" + "foobar" + "0000"
     
     sso = schema_def.classes[0].from_s(ss, schema_def)
     sso.super_attr.class.should == SchemaTestSuper
     sso.super_attr.another_attr.should == "foobar"

     sup1.super_attr = nil
     sup1.another_attr = "money"
     ss = schema_def.classes[0].to_s(sup1, schema_def)
     ss.should == "I" + "0000" + "0005" + "money"

     sso = schema_def.classes[0].from_s(ss, schema_def)
     sso.super_attr.should == nil
  end

  it "should be able to create singleton class from string" do
     schema_def = Schema::Parser.parse(:schema =>
         "<schema>" + 
           "<class name='StandardSingletonTest'>"+ 
             "<member type='str' name='an_attr' />" +
           "</class>" + 
         "</schema>")

     lambda {
       schema_def.classes[0].from_s("I0003foo", schema_def)
     }.should_not raise_error
  end

  it "should raise an error if it fails to create a new object from string" do
     schema_def = Schema::Parser.parse(:schema =>
         "<schema>" + 
           "<class name='CustomSingletonTest'>"+ 
             "<member type='str' name='an_attr' />" +
           "</class>" + 
         "</schema>")

     lambda {
       schema_def.classes[0].from_s("I0000", schema_def)
     }.should raise_error(InvalidSchemaClass, "cannot create schema class CustomSingletonTest")
  end


end

class SchemaTestSuper
   attr_accessor :super_attr
   attr_accessor :another_attr
end

class SchemaTestBase < SchemaTestSuper
   attr_accessor :base_attr
end

class SchemaTestDerived < SchemaTestBase
   attr_accessor :derived_attr
end

class StandardSingletonTest
   include Singleton 
end

# test class where 'new' a 'instance' are not public
class CustomSingletonTest
  attr_accessor :an_attr
  private_class_method :new
end
