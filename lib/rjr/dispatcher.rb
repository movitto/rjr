# RJR Request / Response Dispatcher
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the AGPLv3+ http://www.gnu.org/licenses/agpl.txt

# establish client connection w/ specified args and invoke block w/ 
# newly created client, returning it after block terminates

require 'rjr/common'

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
    @client_ip    = args[:client_ip]
    @client_port  = args[:client_port]
    @rjr_callback = args[:rjr_callback]
    @rjr_node      = args[:rjr_node]
    @rjr_node_id   = args[:rjr_node_id]
    @rjr_node_type = args[:rjr_node_type]
    @handler       = args[:handler]
  end

  def handle
    RJR::Logger.info "Dispatching '#{@method}' request with parameters (#{@method_args.join(',')}) on #{@rjr_node_type}-node(#{@rjr_node_id})"
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
  attr_accessor :error_class

  def initialize(args = {})
    @result        = nil
    @error_code    = nil
    @error_message = nil
    @error_class = nil

    if args.has_key?(:result)
      @success = true
      @failed  = false
      @result  = args[:result]

    elsif args.has_key?(:error_code)
      @success = false
      @failed  = true
      @error_code  = args[:error_code]
      @error_msg   = args[:error_msg]
      @error_class = args[:error_class]

    end
  end

  def ==(other)
    @success == other.success &&
    @failed  == other.failed  &&
    @result  == other.result  &&
    @error_code == other.error_code &&
    @error_msg  == other.error_msg  &&
    @error_class == other.error_class
  end

  def to_s
    "#{@success} #{@result} #{@error_code} #{@error_msg} #{@error_class}"
  end

  ######### Specific request types

  def self.invalid_request
     return Result.new(:error_code => -32600,
                       :error_msg => '  Invalid Request')
  end

  def self.method_not_found(name)
     return Result.new(:error_code => -32602,
                       :error_msg => "Method '#{name}' not found")
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
    return Result.method_not_found(args[:missing_name]) if @method_name.nil?

    begin
      request = Request.new args.merge(:method          => @method_name,
                                       :handler         => @handler_proc)
      retval = request.handle
      return Result.new(:result => retval)

    rescue Exception => e
      RJR::Logger.warn ["Exception Raised in #{method_name} handler #{e}"] + e.backtrace

      return Result.new(:error_code => -32000,
                        :error_msg  => e.to_s,
                        :error_class => e.class)

    end
  end
end

class Dispatcher
  # clear handlers
  def self.init_handlers
    @@handlers = {}
  end

  # register a handler to the specified method
  def self.add_handler(method_names, args = {}, &handler)
    method_names = Array(method_names) unless method_names.is_a?(Array)
    @@handlers  ||= {}
    method_names.each { |method_name|
      @@handlers[method_name] = Handler.new args.merge(:method  => method_name,
                                                       :handler => handler)
    }
  end

  # Helper to handle request messages
  def self.dispatch_request(method_name, args = {})
     @@handlers  ||= {}
     handler  = @@handlers[method_name]

     if handler.nil?
       @@generic_handler ||= Handler.new :method => nil
       return @@generic_handler.handle(args.merge(:missing_name => method_name))
     end

     return handler.handle args
  end

  # Helper to handle response messages
  def self.handle_response(result)
     unless result.success
       #if result.error_class
       #  TODO needs to be constantized first (see TODO in lib/rjr/message)
       #  raise result.error_class.new(result.error_msg) unless result.success
       #else
         raise Exception, result.error_msg
       #end
     end
     return result.result
  end

end

end # module RJR
