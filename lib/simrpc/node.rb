# simrpc node module
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
             # default value support
             if i >= args.size
               field.value = param.to_s(param.default, @schema_def)
             else
               field.value = param.to_s(args[i], @schema_def)
             end
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

               # consruct and send response message using return values
               response = Message::Message.new
               response.header.type = 'response'
               response.header.target = method.name
               (0...method.return_values.size).each { |rvi|
                 field = Message::Field.new
                 field_def = method.return_values[rvi]
                 field.name = field_def.name
                 # can't support default values here since we don't know if the handler return nil intentionally
                 field.value = field_def.to_s(return_values[rvi], @schema_def) unless field_def.nil? # TODO what if field_def is nil
                 response.body.fields.push field
               }
               Logger.info "responding to #{reply_to}"
               node.send_message(reply_to, response)
               return nil

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

      # FIXME XXX big bug, we need a lock per message to allow
      # a node to be able to handle multiple simultaneous messages
      @message_lock = Semaphore.new(1)
      @message_lock.wait

      # FIXME currently not allowing for any other params to be passed into
      # QpidAdapter::Node such as broker ip or port, NEED TO FIX THIS
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
      return nil
   end

   # can invoke schema methods directly on Node instances, this will catch
   # them and send them onto the destination
   def method_missing(method_id, *args)
     send_method(method_id.to_s, @destination, *args)
   end
end

end # module Simrpc
