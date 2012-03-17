# RJR Request / Response Dispatcher
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the AGPLv3+ http://www.gnu.org/licenses/agpl.txt

# establish client connection w/ specified args and invoke block w/ 
# newly created client, returning it after block terminates

module RJR

class Request
  attr_accessor :method
  attr_accessor :method_args
  attr_accessor :headers
  attr_accessor :rjr_callback
  attr_accessor :rjr_node_type
  attr_accessor :rjr_node_id

  attr_accessor :handler

  def initialize(args = {})
    @method       = args[:method]
    @method_args  = args[:method_args]
    @headers      = args[:headers]
    @rjr_callback = args[:rjr_callback]
    @rjr_node_id   = args[:rjr_node_id]
    @rjr_node_type = args[:rjr_node_type]
    @handler       = args[:handler]
  end

  def handle
    RJR::Logger.info "Dispatching '#{@method}' request with parameters (#{@method_args.join(',')})"
    retval = instance_exec(*@method_args, &@handler)
    RJR::Logger.info "#{@method} request with parameters (#{@method_args.join(',')}) returning #{retval}"
    return retval
  end
end

class Result
  attr_accessor :success
  attr_accessor :failed
  attr_accessor :result
  attr_accessor :error_code
  attr_accessor :error_msg

  def initialize(args = {})
    @result        = nil
    @error_code    = nil
    @error_message = nil

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

class Handler
  attr_accessor :method_name
  attr_accessor :handler_proc

  def initialize(args = {})
    @method_name          = args[:method]
    @handler_proc         = args[:handler]
  end

  def handle(args = {})
    return Result.method_not_found if @method_name.nil?

    begin
      request = Request.new args.merge(:method          => @method_name,
                                       :handler         => @handler_proc)
      retval = request.handle
      return Result.new(:result => retval)

    rescue Exception => e
      RJR::Logger.warn "Exception Raised in #{method_name} handler #{e}"
      e.backtrace.each { |b| RJR::Logger.warn b }
      # TODO store exception class to be raised later

      return Result.new(:error_code => -32000,
                        :error_msg  => e.to_s)

    end
  end
end

class Dispatcher
  # register a handler to the specified method
  def self.add_handler(method_name, args = {}, &handler)
    @@handlers  ||= {}
    @@handlers[method_name] = Handler.new args.merge(:method  => method_name,
                                                     :handler => handler)
  end

  # Helper to handle request messages
  def self.dispatch_request(method_name, args = {})
     @@handlers  ||= {}
     handler  = @@handlers[method_name]

     if handler.nil?
       @@generic_handler ||= Handler.new :method => nil
       return @@generic_handler.handle(args)
     end

     return handler.handle args
  end

  # Helper to handle response messages
  def self.handle_response(result)
     # TODO raise exception corresponding to one caught in Handler::handle above
     raise Exception.new(result.error_msg) unless result.success
     return result.result
  end

end

end # module RJR
