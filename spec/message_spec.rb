# simrpc message spec
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

describe "Simrpc::Message" do

  ################## test message module

  it "should format and parse a data field" do
     formatted = Message::Formatter::format_with_size("foobar")
     formatted.should == "00000006foobar"
     assert_equal ["foobar", ""], Message::Formatter::parse_from_formatted(formatted)
  end

  it "should format and parsed a data field with a fixed size" do
     formatted = Message::Formatter::format_with_fixed_size(3, 123456)
     formatted.should == "123"
     assert_equal ["123", ""], Message::Formatter::parse_from_formatted_with_fixed_size(3, formatted)
  end

  it "should convert a field to and from a string" do
     field = Message::Field.new(:name => "foo", :value => "bar")
     field_s = field.to_s
     field_s.should == "00000003foo00000003bar"

     field_o = Message::Field.from_s(field_s)
     field_o.name.should == "foo"
     field_o.value.should == "bar"
  end

  it "should convert a message header to and from a string" do
     header = Message::Header.new(:target => "footarget")
     header_s = header.to_s
     header_s.should == "0000000000000009footarget"

     header_o = Message::Header.from_s(header_s)
     header.type.should == ""
     header.target.should == "footarget"
  end

  it "should convert a message body to and from a string" do
     body = Message::Body.new
     body.fields.push Message::Field.new(:name => "foo", :value => "bar")
     body.fields.push Message::Field.new(:name => "money", :value => "lotsof")
     body_s = body.to_s
     body_s.should == "0000002200000003foo00000003bar0000002700000005money00000006lotsof"

     body_o = Message::Body.from_s(body_s)
     body_o.fields.size.should == 2
     body_o.fields[0].name.should == "foo"
     body_o.fields[0].value.should == "bar"
     body_o.fields[1].name.should == "money"
     body_o.fields[1].value.should == "lotsof"
  end

  it "should convert a message to and from a string" do
     msg = Message::Message.new
     msg.header.id = "12345678"
     msg.header.type = 'request'
     msg.header.target = 'method'
     msg.body.fields.push Message::Field.new(:name => "foo", :value => "bar")
     msg.body.fields.push Message::Field.new(:name => "money", :value => "lotsof")
     msg_s = msg.to_s

     msg_s.should == "000000371234567800000007request00000006method000000650000002200000003foo00000003bar0000002700000005money00000006lotsof"
     
     msg_o = Message::Message.from_s(msg_s)
     msg_o.header.type.should == 'request'
     msg_o.header.target.should == 'method'
     msg_o.body.fields.size.should == 2
     msg_o.body.fields[0].name.should == 'foo'
     msg_o.body.fields[0].value.should == 'bar'
     msg_o.body.fields[1].name.should == 'money'
     msg_o.body.fields[1].value.should == 'lotsof'
  end

end
