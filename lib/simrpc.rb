# simrpc - simple remote procedure call library
#
# Implements a simple to use method based RPC for ruby
# built upon Apache Qpid
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

require 'rexml/document'
require 'logger'

require 'qpid'
require 'socket'
require 'semaphore'

require 'activesupport' # for inflector demodulize

module Simrpc

# Logger helper class
class Logger
  private
    def self._instantiate_logger
       unless defined? @@logger
         @@logger = ::Logger.new(STDOUT)
         @@logger.level = ::Logger::FATAL # FATAL ERROR WARN INFO DEBUG
       end
    end
  public
    def self.method_missing(method_id, *args)
       _instantiate_logger
       @@logger.send(method_id, args)
    end
end

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

# FIXME store lengths in binary instead of ascii string

# Data field defintion containing a type, name, and value.
# Optinally an associated class or type may be given.
# Associated only valid for :obj and :array types, and
#  must be set to associated ClassDef or Type (:array only)
class DataFieldDef
  attr_accessor :type, :name, :associated

  # indicates this data field should be ignored if it has a null value
  attr_accessor :ignore_null

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
         cl_name = "%04d" % cl_name.size + cl_name
       end

       return cl_name + cl_def.to_s(value, schema_def, converted_classes) unless cl_def.nil?

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
      #parsed = str[4...4+len]
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
      end

      return cl_def.from_s(str, schema_def, converted_classes) unless cl_def.nil?

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
   attr_accessor :name, :members

   def initialize
     @members    = []
   end

   # convert value instance of class represented by this ClassDef
   # into a string. schema_def must be provided if this ClassDef
   # contains any associated class members. converted_classes is 
   # a recursive helper array used internally
   def to_s(value, schema_def = nil, converted_classes = [])
      return "O" + ("%04d" % converted_classes.index(value)) if converted_classes.include? value # if we already converted the class, store 'O' + its index
      converted_classes.push value

      # just encode each member w/ length
      str = ""
      unless value.nil?
        @members.each { |member|
           mval = value.send(member.name.intern)
           #mval = value.method(member.name.intern).call # invoke member getter
           mstr = member.to_s(mval, schema_def, converted_classes)
           mlen = "%04d" % mstr.size
           #unless mstr == "" && member.ignore_null
           str += mlen + mstr
           #end
        }
      end
      return str
   end

   # convert string instance of class represented by this ClassDef
   # into actual class instance. schema_def must be provided if this
   # ClassDef contains any associated class members. converted_classes
   # is a recurvice helper array used internally.
   def from_s(str, schema_def = nil, converted_classes = [])
      return nil if str == ""

      mpos = 0
      if str[mpos,1] == "O" # if we already converted the class, simply return that
         return converted_classes[str[1...5].to_i]
      end

      # construct an instance of the class
      obj = Object.module_eval("::#{@name}", __FILE__, __LINE__).new
      converted_classes.push obj

      # decode each member
      @members.each { |member|
        mlen = str[mpos...mpos+4].to_i
        parsed = str[mpos+4...mpos+4+mlen]
        parsed_o = member.from_s(parsed, schema_def, converted_classes)
        unless parsed_o.nil? && member.ignore_null
           obj.send(member.name + "=", parsed_o) # invoke member setter
        end
        mpos = mpos+4+mlen
      }

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
     data_field.associated = element.attributes["associated"].intern unless element.attributes["associated"].nil?
     data_field.ignore_null = true if element.attributes.include? "ignore_null"
     return data_field
   end
end

end

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

end

# The QpidAdapter module implements the simrpc qpid subsystem, providing
# a convenient way to access qpid constructs
module QpidAdapter

# Simrpc::Qpid::Node class, represents an enpoint  on a qpid
# network which has its own exchange and queue which it listens on
class Node
 private
  # helper method to generate a random id
  def gen_uuid
    ["%02x"*4, "%02x"*2, "%02x"*2, "%02x"*2, "%02x"*6].join("-") %
        Array.new(16) {|x| rand(0xff) }
  end

 public
  # a node can have children nodes mapped to by keys
  attr_accessor :children

  # node always has a node id
  attr_reader :node_id

  # create the qpid base connection with the specified broker / port
  # or config file. Then establish exchange and queue and start listening
  # for requests.
  #
  # specify :broker and :port arguments to directly connect to those
  # specify :config argument to use that yml file
  # specify MOTEL_AMQP_CONF environment variable to use that yml file
  # specify :id parameter to set id, else it will be set to a uuid just created
  def initialize(args = {})
     # if no id specified generate a new uuid
     @node_id = args[:id].nil? ? gen_uuid : args[:id]

     # we generate a random session id
     @session_id = gen_uuid

     # get the broker/port
     broker = args[:broker].nil? ? "localhost"  : args[:broker]
     port   = args[:port].nil? ? 5672  : args[:port]

     if (broker.nil? || port.nil?) && args.has_key?(:config)
       config      =
       amqpconfig = YAML::load(File.open(args[:config]))
       broker = amqpconfig["broker"] if broker.nil?
       port   = amqpconfig["port"]   if port.nil?
     end

     ### create underlying tcp connection
     @conn = Qpid::Connection.new(TCPSocket.new(broker,port))
     @conn.start

     ### connect to qpid broker
     @ssn = @conn.session(@session_id)

     @children = {}

     @accept_lock = Semaphore.new(1)

     # qpid constructs that will be created for node
     @exchange     = args[:exchange].nil?    ? @node_id.to_s + "-exchange"    : args[:exchange]
     @queue        = args[:queue].nil?       ? @node_id.to_s + "-queue"       : args[:queue]
     @local_queue  = args[:local_queue].nil? ? @node_id.to_s + "-local-queue" : args[:local_queue]
     @routing_key  = @queue

     Logger.warn "creating qpid exchange #{@exchange} queue #{@queue} binding_key #{@routing_key}"

     if @ssn.exchange_query(@exchange).not_found
       @ssn.exchange_declare(@exchange, :type => "direct")
     end

     if @ssn.queue_query(@queue).queue.nil?
       @ssn.queue_declare(@queue)
     end

     @ssn.exchange_bind(:exchange => @exchange,
                        :queue    => @queue,
                        :binding_key => @routing_key)
  end

  # Instruct Node to start accepting requests asynchronously and immediately return.
  # handler must be callable and take node, msg, respond_to arguments, corresponding to
  # 'self', the message received', and the routing_key which to send any response.
  def async_accept(&handler)
     # TODO permit a QpidNode to accept messages from multiple exchanges/queues
     @accept_lock.wait

     # subscribe to the queue
     @ssn.message_subscribe(:destination => @local_queue,
                            :queue => @queue,
                            :accept_mode => @ssn.message_accept_mode.none)
     @incoming = @ssn.incoming(@local_queue)
     @incoming.start

     Logger.warn "listening for messages on #{@queue}"

     # start receiving messages
     @incoming.listen{ |msg|
        Logger.info "queue #{@queue} received message #{msg.body.to_s.size} #{msg.body}"
        reply_to = msg.get(:message_properties).reply_to.routing_key
        handler.call(self, msg.body, reply_to)
     }
  end

  # block until accept operation is complete
  def join
     @accept_lock.wait
  end

  # instructs QpidServer to stop accepting, blocking
  # untill all accepting operations have terminated
  def terminate
    Logger.warn "terminating qpid session"
    unless @incoming.nil?
      @incoming.stop
      @incoming.close
      @accept_lock.signal
    end
    @ssn.close
    # TODO undefine the @queue/@exchange
  end

  # send a message to the specified routing_key
  def send_message(routing_key, message)
    dp = @ssn.delivery_properties(:routing_key => routing_key)
    mp = @ssn.message_properties( :content_type => "text/plain")
    rp = @ssn.message_properties( :reply_to =>
                                  @ssn.reply_to(@exchange, @routing_key))
    msg = Qpid::Message.new(dp, mp, rp, message.to_s)

    Logger.warn "sending qpid message #{msg.body} to #{routing_key}"

    # send it
    @ssn.message_transfer(:message => msg)
  end

end

end

# Simrpc Method Message Controller, generates and handles method messages
class MethodMessageController
  public
    # initialize with a specified schema definition
    def initialize(schema_def)
      @schema_def = schema_def
    end

    # generate new new method message, setting the message
    # target to the specified method name, and setting the fields
    # on the message to the method arguments
    def generate(method_name, args)
       @schema_def.methods.each { |method|
         if method.name == method_name
           msg = Message::Message.new
           msg.header.type = 'request'
           msg.header.target = method.name

           # loop through each param, convering corresponding
           # argument to message field and adding it to msg
           i = 0
           method.parameters.each { |param|
             field = Message::Field.new
             field.name = param.name
             field.value = param.to_s(args[i], @schema_def)
             msg.body.fields.push field
             i += 1
           }

           return msg
         end
       }
       return nil
    end

    # should be invoked when a message is received,
    # takes a message, converts it into a method call, and calls the corresponding
    # handler in the provided schema. Takes return arguments and sends back to caller
    def message_received(node, message, reply_to)
       message = Message::Message::from_s(message)
       @schema_def.methods.each { |method|

         if method.name == message.header.target
           Logger.info "received method #{method.name} message "

           # for request messages, dispatch to method handler
           if message.header.type != 'response' && method.handler != nil
               # order the params
               params = []
               method.parameters.each { |data_field|
                 value_field = message.body.fields.find { |f| f.name == data_field.name }
                 params.push data_field.from_s(value_field.value, @schema_def) unless value_field.nil? # TODO what if value_field is nil
               }

               Logger.info "invoking #{method.name} handler "

               # invoke method handler
               return_values = method.handler.call(*params)  # FIXME handlers can't use 'return' as this will fall through here
                                                             # FIXME throw a catch block around this call to catch all handler exceptions
               return_values = [return_values] unless return_values.is_a? Array

               # if method returns no values, do not return response
               unless method.return_values.size == 0

                  # consruct and send response message using return values
                  response = Message::Message.new
                  response.header.type = 'response'
                  response.header.target = method.name
                  (0...method.return_values.size).each { |rvi|
                    field = Message::Field.new
                    field.name = method.return_values[rvi].name
                    field_def = method.return_values.find { |rv| rv.name == field.name }
                    field.value = field_def.to_s(return_values[rvi], @schema_def) unless field_def.nil? # TODO what if field_def is nil
                    response.body.fields.push field
                  }
                  Logger.info "responding to #{reply_to}"
                  node.send_message(reply_to, response)

               end

           # for response values just return converted return values
           else
               results = []
               method.return_values.each { |data_field|
                 value_field = message.body.fields.find { |f| f.name == data_field.name }
                 results.push data_field.from_s(value_field.value, @schema_def) unless value_field.nil? # TODO what if value_field is nil
               }
               return results
           end
         end
       }
    end
end

# Simrpc Node represents ths main api which to communicate and send/listen for data.
class Node

   # Instantiate it w/ a specified id
   # or one will be autogenerated. Specify schema (or location) containing
   # data and methods which to invoke and/or handle. Optionally specify
   # a remote destination which to send new messages to. Automatically listens
   # for incoming messages.
   def initialize(args = {})
      @id = args[:id] if args.has_key? :id
      @schema = args[:schema]
      @schema_file = args[:schema_file]
      @destination = args[:destination]

      if !@schema.nil?
        @schema_def = Schema::Parser.parse(:schema => @schema)
      elsif !@schema_file.nil?
        @schema_def = Schema::Parser.parse(:file => @schema_file)
      end
      raise ArgumentError, "schema_def cannot be nil" if @schema_def.nil?
      @mmc = MethodMessageController.new(@schema_def)
      @message_lock = Semaphore.new(1)
      @message_lock.wait

      @qpid_node = QpidAdapter::Node.new(:id => @id)
      @qpid_node.async_accept { |node, msg, reply_to|
          results = @mmc.message_received(node, msg, reply_to)
          message_received(results)
      }
   end

   def id
     return @id unless @id.nil?
     return @qpid_node.node_id
   end

   # implements, message_received callback to be notified when qpid receives a message
   def message_received(results)
       @message_results = results
       @message_lock.signal
   end

   # wait until the node is no longer accepting messages
   def join
       @qpid_node.join
   end

   # add a handler which to invoke when an schema method is invoked
   def handle_method(method, &handler)
      @schema_def.methods.each { |smethod|
         if smethod.name == method.to_s
             smethod.handler = handler
             break
         end
      }
   end

   # send method request to remote destination w/ the specified args
   def send_method(method_name, destination, *args)
      # generate and send new method message
      msg = @mmc.generate(method_name, args)
      @qpid_node.send_message(destination + "-queue", msg)

      # FIXME race condition if response is received b4 wait is invoked

      # block if we are expecting return values
      if @schema_def.methods.find{|m| m.name == method_name}.return_values.size != 0
        @message_lock.wait # block until response received

        # return return values
        #@message_received.body.fields.collect { |f| f.value }
        return *@message_results
      end
   end

   # can invoke schema methods directly on Node instances, this will catch
   # them and send them onto the destination
   def method_missing(method_id, *args)
     send_method(method_id.to_s, @destination, *args)
   end
end

end # module Simrpc
