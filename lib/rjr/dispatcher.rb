# RJR Request / Response Dispatcher
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the AGPLv3+ http://www.gnu.org/licenses/agpl.txt

# establish client connection w/ specified args and invoke block w/ 
# newly created client, returning it after block terminates

module RJR

class Result
  attr_accessor :success
  attr_accessor :failed
  attr_accessor :result
  attr_accessor :error_code
  attr_accessor :error_msg

  def initialize(args = {})
    if args.has_key?(:result)
      @success = true
      @failed  = false
      @result  = args[:result]
    elsif args.has_key?(:error_code)
      @success = false
      @failed  = true
      @error_code  = args[:error_code]
      @error_msg   = args[:error_msg]
    end
  end

  def to_s
    "#{@success} #{@result} #{@error_code} #{@error_msg}"
  end

  ######### Specific request types

  def self.invalid_request
     return Result.new(:error_code => -32600,
                       :error_msg => '  Invalid Request')
  end

  def self.method_not_found
     return Result.new(:error_code => -32602,
                       :error_msg => 'Method not found')
  end

end

class Dispatcher
  # register a handler to the specified method
  def self.add_handler(method, &handler)
    @@handlers  ||= {}
    @@handlers[method] = handler
  end

  # register a callback to the specified method.
  # a callback is the same as a handler except it takes an additional argument
  # specifying the node callback instance to use to send data back to client
  def self.add_callback(method, &handler)
    @@callbacks  ||= {}
    @@callbacks[method] = handler
  end

  # Helper to handle request messages
  def self.dispatch_request(args = {})
     @method   = args[:method]
     @method_args = args[:method_args]
     @headers  = args[:headers]
     @node_callback = args[:node_callback]

     @@handlers  ||= {}
     @@callbacks ||= {}
     handler  = @@handlers[@method]
     callback = @@callbacks[@method]

     if !handler.nil?
       begin
         retval = instance_exec(*@method_args, &handler)
         #retval = handler.call(*method_args)
         return Result.new(:result => retval)
       #rescue Exception => e
         return Result.new(:error_code => -32000,
                           :error_msg  => e.to_s)
       end

     elsif !callback.nil?
       # ; if node_callback.nil? # TODO handle callback method invoked via node type that doesn't support callbacks
       begin
         @method_args.unshift(@node_callback) # FIXME remove
         retval = instance_exec(*@method_args, &callback)
         return Result.new(:result => retval)
       rescue Exception => e
         return Result.new(:error_code => -32000,
                           :error_msg  => e.to_s)
       end

     else
       return Result.method_not_found

     end

     return nil
  end

  # Helper to handle response messages
  def self.handle_response(args = {})
     result   = args[:result]
     response = args[:response]
     headers  = args[:headers]

     raise Exception.new(result.error_msg) unless result.success
     return result.result
  end

end

end # module RJR
