# simrpc message module
#
# Copyright (C) 2010 Mohammed Morsi <movitto@yahoo.com>
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

module Simrpc

# the message module provides the Message definition,
# including a header with routing info and a body
# with any number of data fields
module Message

# Simrpc::Message formatter helper module
class Formatter

  # helper method to format a data field,
  # prepending a fixed size to it
  def self.format_with_size(data)
    # currently size is set to a 8 digit int
    len = "%08d" % data.to_s.size
    len + data.to_s
  end

  # helper method to parse a data field
  # off the front of a data sequence, using the
  # formatted size. Returns parsed data field
  # and remaining data sequence. If optional
  # class is given, the from_s method will
  # be invoked w/ the parsed data field and
  # returned with the remaining data sequence
  # instead
  def self.parse_from_formatted(data, data_class = nil)
     len = data[0...8].to_i
     parsed = data[8...8+len]
     remaining = data[8+len...data.size]
     return parsed, remaining if data_class.nil?
     return data_class.from_s(parsed), remaining
  end
end

# a single field trasnmitted via a message,
# containing a key / value pair
class Field
  attr_accessor :name, :value

  def initialize(args = {})
    @name   = args[:name].nil?  ? "" : args[:name]
    @value  = args[:value].nil? ? "" : args[:value]
  end

  def to_s
    Formatter::format_with_size(@name) + Formatter::format_with_size(@value)
  end

  def self.from_s(data)
    field = Field.new
    field.name,  data = Formatter::parse_from_formatted(data)
    field.value, data = Formatter::parse_from_formatted(data)
    return field
  end
end

# header contains various descriptive properies
# about a message
class Header
  attr_accessor :type, :target

  def initialize(args = {})
     @type   = args[:type].nil?   ? "" : args[:type]
     @target = args[:target].nil? ? "" : args[:target]
  end

  def to_s
    Formatter::format_with_size(@type) + Formatter::format_with_size(@target)
  end

  def self.from_s(data)
    header = Header.new
    header.type,   data = Formatter::parse_from_formatted(data)
    header.target, data = Formatter::parse_from_formatted(data)
    return header
  end
end

# body consists of a list of data fields
class Body
   attr_accessor :fields

   def initialize
     @fields = []
   end

   def to_s
      s = ''
      @fields.each { |field|
        fs = field.to_s
        s += Formatter::format_with_size(fs)
      }
      return s
   end

   def self.from_s(data)
     body = Body.new
     while(data != "")
        field, data = Formatter::parse_from_formatted(data)
        field = Field.from_s field
        body.fields.push field
     end
     return body
   end
end

# message contains a header / body
class Message
   attr_accessor :header, :body

   def initialize
      @header = Header.new
      @body   = Body.new
   end

   def to_s
      Formatter::format_with_size(@header) + Formatter::format_with_size(@body)
   end

   def self.from_s(data)
      message = Message.new
      message.header, data = Formatter::parse_from_formatted(data, Header)
      message.body,   data = Formatter::parse_from_formatted(data, Body)
      return message
   end
end

end # module Message

end # module Simrpc
