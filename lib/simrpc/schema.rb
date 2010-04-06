# simrpc schema module
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

require 'rexml/document'

# FIXME store lengths in binary instead of ascii string

module Simrpc

# schema module defines classes / methods to define
# a simrpc schema / load it from an xml file
module Schema

Types = [ :str, :int, :float, :bool, :obj, :array ]

# return true if type is a primitive, else false
def is_primitive?(type)
   return [:str, :int, :float, :bool].include?(type)
end
module_function :is_primitive?

# convert primitive type from string
def primitive_from_str(type, str)
  if type == :str
     return str

  elsif type == :int
     return str.to_i

  elsif type == :float
     return str.to_f

  elsif type == :bool
     return str == "true"

  end
end
module_function :primitive_from_str

# Data field defintion containing a type, name, and value.
# Optinally an associated class or type may be given.
# Associated only valid for :obj and :array types, and
#  must be set to associated ClassDef or Type (:array only)
class DataFieldDef
  attr_accessor :type, :name, :associated

  # Indicates this data field should be ignored if it has a null value
  attr_accessor :ignore_null

  # Indicates the default value of the field
  attr_accessor :default

  def initialize(args = {})
     @type = args[:type] unless args[:type].nil?
     @name = args[:name] unless args[:name].nil?
     @associated = args[:associated] unless args[:associated].nil?
     @ignore_null = !args[:ignore_null].nil? && args[:ignore_null]
  end

  # helper method to lookup and return the specified class name in the
  # specified schema
  def find_class_def(cl_name, schema_def)
    return schema_def.classes.find { |cl| cl.name == cl_name.to_s } unless cl_name.nil? || schema_def.nil?
    nil
  end

  # helper method to lookup and return the class definition corresponding to the associated
  # attribte in the specified schema def
  def associated_class_def(schema_def)
    find_class_def(@associated, schema_def) unless @associated.nil? 
  end

  # convert given value of this data field into a string. Provide schema_def
  # for :obj or :array data fields associated w/ a non-primitive type. converted_classes
  # is a recursive helper array used/maintained internally
  def to_s(value, schema_def = nil, converted_classes = [])
     if value.nil?
        return ""
     elsif Schema::is_primitive?(@type)
       return value.to_s

     elsif type == :array
       str = "%04d" % value.size
       value.each { |val|
         if Schema::is_primitive?(@associated)
            str += "%04d" % val.to_s.size
            str += val.to_s
         else
            cl_def = associated_class_def(schema_def)
            unless cl_def.nil?
              cl_s = cl_def.to_s(val, schema_def, converted_classes)
              str += "%04d" % cl_s.size
              str += cl_s
            end
         end
       }
       return str

    # elsif @type == :map # TODO

     elsif type == :obj
       cl_name = ""
       cl_def = associated_class_def(schema_def)

       # if associated class isn't specified,  store the class name,
       # providing for generic object support
       if cl_def.nil?
         cl_name = value.class.to_s.demodulize
         cl_def = find_class_def(cl_name, schema_def)
         raise InvalidSchemaClass.new("cannot find #{cl_name} in schema") if cl_def.nil?
         cl_name = "%04d" % cl_name.size + cl_name
       end

       return cl_name + cl_def.to_s(value, schema_def, converted_classes)
     end
  end

  # convert given string representation of this data field into its original value.
  # Provide schema_def for :obj or :array data fields associated w/ non-primitive types
  # # coverted_classes is a recursive helper array used/maintained internally
  def from_s(str, schema_def = nil, converted_classes = [])
    if str == ""
      return nil

    elsif Schema::is_primitive?(@type)
      return Schema::primitive_from_str(@type, str)

    elsif @type == :array
      res = []
      cl_def = associated_class_def(schema_def) unless Schema::is_primitive?(@associated)
      alen = str[0...4].to_i
      apos = 4
      (0...alen).each { |i|
        elen = str[apos...apos+4].to_i
        parsed = str[apos+4...apos+4+elen]
        if Schema::is_primitive?(@associated)
          p =  Schema::primitive_from_str(@associated, parsed)
          res.push p
        else
          res.push cl_def.from_s(parsed, schema_def, converted_classes)
        end
        apos = apos+4+elen
      }
      return res

    # elsif @type == :map # TODO

    elsif @type == :obj
      cl_def = associated_class_def(schema_def)

      # if associated class isn't specified,  parse the class name, 
      # providing for generic object support
      if cl_def.nil?
        cnlen = str[0...4].to_i
        cname = str[4...cnlen+4]
        str = str[cnlen+4...str.size]
        cl_def = find_class_def(cname, schema_def)
        raise InvalidSchemaClass.new("cannot find #{cname} in schema") if cl_def.nil?
      end

      return cl_def.from_s(str, schema_def, converted_classes)

    end
  end

end

# A class definition, containing data members.
# Right now we build into this the assumption that
# the 'name' attribute will share the same name as
# the actual class name which data will be mapped to / from
# and accessors exist on it corresponding to the names of
# each of the members
class ClassDef
   # class name
   # array of DataFieldDef
   # base class name
   attr_accessor :name, :members, :inherits

   def initialize
     @members    = []
   end

   def base_class_def(schema_def)
    return schema_def.classes.find { |cl| cl.name == inherits.to_s } unless inherits.nil? || schema_def.nil?
   end

   # convert value instance of class represented by this ClassDef
   # into a string. schema_def must be provided if this ClassDef
   # contains any associated class members. converted_classes is 
   # a recursive helper array used internally
   def to_s(value, schema_def = nil, converted_classes = [])
      return "O" + ("%04d" % converted_classes.index(value)) if converted_classes.include? value # if we already converted the class, store 'O' + its index
      converted_classes.push value

      # just encode each member w/ length
      str = "I" # NEED to have something here incase the length of the first member is the same as the ascii character for 'O'
      unless value.nil?
        @members.each { |member|
           mval = value.send(member.name.intern) if value.respond_to? member.name.intern
           #mval = value.method(member.name.intern).call # invoke member getter
           mstr = member.to_s(mval, schema_def, converted_classes)
           mlen = "%04d" % mstr.size
           #unless mstr == "" && member.ignore_null
           str += mlen + mstr
           #end
        }

        # encode and append base class
        base_class = base_class_def(schema_def)
        until base_class.nil?
          base_class.members.each { |member|
             mval = value.send(member.name.intern) if value.respond_to? member.name.intern
             mstr = member.to_s(mval, schema_def, converted_classes)
             mlen = "%04d" % mstr.size
             str += mlen + mstr
          }
          base_class = base_class.base_class_def(schema_def)
        end
      end

      return str
   end

   # convert string instance of class represented by this ClassDef
   # into actual class instance. schema_def must be provided if this
   # ClassDef contains any associated class members. 
   # The converted_classes recursive helper array is used internally.
   def from_s(str, schema_def = nil, converted_classes = [])
      return nil if str == "I"

      if str[0] == "O" # if we already converted the class, simply return that
         return converted_classes[str[1...5].to_i]
      end

      # construct an instance of the class
      cl = Object.module_eval("::#{@name}", __FILE__, __LINE__)
      obj = cl.new if cl.respond_to? :new
      obj = cl.instance if obj.nil? && cl.respond_to?(:instance)
      raise InvalidSchemaClass.new("cannot create schema class #{@name}") if obj.nil?

      # decode each member
      mpos = 1 # start at 1 to skip the 'I'
      @members.each { |member|
        mlen = str[mpos...mpos+4].to_i
        parsed = str[mpos+4...mpos+4+mlen]
        parsed_o = member.from_s(parsed, schema_def, converted_classes)
        unless parsed_o.nil? && member.ignore_null
           member_method = (member.name + "=").intern
           obj.send(member_method, parsed_o) if obj.respond_to? member_method # invoke member setter
        end
        mpos = mpos+4+mlen
      }

      # decode base object from string
      base_class = base_class_def(schema_def)
      until base_class.nil?
        base_class.members.each { |member|
          mlen = str[mpos...mpos+4].to_i
          parsed = str[mpos+4...mpos+4+mlen]
          parsed_o = member.from_s(parsed, schema_def, converted_classes)
          unless parsed_o.nil? && member.ignore_null
             member_method = (member.name + "=").intern
             obj.send(member_method, parsed_o) if obj.respond_to? member_method # invoke member setter
          end
          mpos = mpos+4+mlen
        }

        base_class = base_class.base_class_def(schema_def)
      end

      return obj
   end
end

# method definition, containing parameters
# and return values. May optionally have
# a handler to be invoked when a remote
# entity invokes this method
class MethodDef
   attr_accessor :name

   # both are arrays of DataFieldDef
   attr_accessor :parameters, :return_values

   # should be a callable entity that takes
   # the specified parameters, and returns
   # the specified return values
   attr_accessor :handler

   def initialize
     @parameters    = []
     @return_values = []
   end
end

# schema defintion including all defined classes and methods
class SchemaDef
   # array of ClassDef
   attr_accessor :classes

   # array of MethodDef
   attr_accessor :methods

   def initialize
      @classes = []
      @methods = []
   end
end

# parse classes, methods, and data out of a xml definition
class Parser

   # Parse and return a SchemaDef.
   # Specify :schema argument containing xml schema to parse
   # or :file containing location of file containing xml schema
   def self.parse(args = {})
      if(!args[:schema].nil?)
         schema = args[:schema]
      elsif(!args[:file].nil?)
         schema = File.new(args[:file], "r")
      end

      schema_def = SchemaDef.new

      unless schema.nil? || schema == ""
         doc = REXML::Document.new(schema)
         # grab each method definition
         doc.elements.each('schema/method') do |ele|
            method = MethodDef.new
            method.name = ele.attributes["name"]
            Logger.debug "parsed schema method #{method.name}"

            ele.elements.each("param") do |param|
              param = _parse_data_def(param)
              method.parameters.push param
              Logger.debug "    parameter #{param.name}"
            end

            ele.elements.each("return_value") do |rv|
              rv = _parse_data_def(rv)
              method.return_values.push rv
              Logger.debug "    return_value #{rv.name}"
            end

            schema_def.methods.push method
         end

         # grab each class definition
         doc.elements.each('schema/class') do |ele|
            cl = ClassDef.new
            cl.name = ele.attributes["name"]
            cl.inherits = ele.attributes["inherits"]
            Logger.debug "parsed schema class #{cl.name}"

            ele.elements.each("member") do |mem|
              mem = _parse_data_def(mem)
              cl.members.push mem
              Logger.debug "    member #{mem.name}"
            end

            schema_def.classes.push cl
         end
      end
      return schema_def
   end

 private
   # helper method to parse a DataFieldDef out of an Element
   def self._parse_data_def(element)
     data_field = DataFieldDef.new
     data_field.type = element.attributes["type"].intern
     data_field.name = element.attributes["name"]
     data_field.default = data_field.from_s(element.attributes["default"]) unless element.attributes["default"].nil?
     data_field.associated = element.attributes["associated"].intern unless element.attributes["associated"].nil?
     data_field.ignore_null = true if element.attributes.include? "ignore_null"
     data_field
     return data_field
   end
end

end # module Schema
end # module Simrpc
