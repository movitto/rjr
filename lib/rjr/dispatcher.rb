# RJR Dispatcher
#
# Mechanisms which to register methods to handle requests
# and return responses
#
# Copyright (C) 2012-2014 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'rjr/request'
require 'rjr/result'

module RJR

# Primary RJR JSON-RPC method dispatcher.
class Dispatcher
  # Registered json-rpc request signatures and corresponding handlers
  attr_reader :handlers

  # Registered json-rpc request signatures and environments which to execute handlers in
  attr_reader :environments

  # Flag toggling whether or not to keep requests (& responses) around.
  attr_accessor :keep_requests

  # Requests which have been dispatched
  def requests
    @requests_lock.synchronize { Array.new(@requests) }
  end

  # Store request if configured to do so
  def store_request(request)
    @requests_lock.synchronize { @requests << request } if @keep_requests
  end

  # RJR::Dispatcher intializer
  def initialize(args = {})
    @keep_requests = args[:keep_requests] || false

    clear!
    @requests_lock = Mutex.new
  end

  # Return dispatcher to its initial state
  def clear!
    @handlers      = {}
    @environments  = {}
    @requests      = []
  end

  # Loads module from fs and adds handlers defined there
  # 
  # Assumes module includes a 'dispatch_<module_name>' method
  # which accepts a dispatcher and defines handlers on it.
  #
  # @param [String] name location which to load module(s) from, may be
  #   a file, directory, or path specification (dirs seperated with ':')
  # @return self
  def add_module(name)
    require name

    m = name.downcase.gsub(File::SEPARATOR, '_')
    method("dispatch_#{m}".intern).call(self)

    self
  end
  alias :add_modules :add_module

  # Register json-rpc handler with dispatcher
  #
  # @param [String,Regex] signature request signature to match
  # @param [Callable] callable callable object which to bind to signature
  # @param [Callable] &bl block parameter will be set to callback if specified
  # @return self
  def handle(signature, callback = nil, &bl)
    if signature.is_a?(Array)
      signature.each { |s| handle(s, callback, &bl) }
      return self
    end
    @handlers[signature] = callback unless callback.nil?
    @handlers[signature] = bl       unless bl.nil?
    self
  end

  # Return handler for specified method.
  #
  # Currently we match method name string or regex against signature
  # @param [String] string rjr method to match
  # @return [Callable, nil] callback proc registered to handle rjr_method
  #   or nil if not found
  def handler_for(rjr_method)
    handler = @handlers.find { |k,v|
      k.is_a?(String) ? (k == rjr_method) : (k =~ rjr_method)
    }

    handler.nil? ? nil : handler.last
  end

  # Return boolean indicating if dispatcher can handle method
  #
  # @param [String] string rjr method to match
  # @return [true,false] indicating if requests to specified method will be matched
  def handles?(rjr_method)
    !handler_for(rjr_method).nil?
  end

  # Register environment to run json-rpc handler w/ dispatcher.
  #
  # Currently environments may be set to modules which requests
  # will extend before executing handler
  #
  # @param [String,Regex] signature request signature to match
  # @param [Module] module which to extend requests with
  # @return self
  def env(signature, environment)
    if signature.is_a?(Array)
      signature.each { |s| env(s, environment) }
      return self
    end
    @environments[signature] = environment
    self
  end

  # Return the environment registered for the specified method
  def env_for(rjr_method)
     env = @environments.find { |k,v|
       k.is_a?(String) ? (k == rjr_method) : (k =~ rjr_method)
     }

     env.nil? ? nil : env.last
  end

  # Dispatch received request. (used internally by nodes).
  #
  # Arguments should include :rjr_method and other parameters
  # required to construct a valid Request instance
  def dispatch(args = {})
    rjr_method = args[:rjr_method]

    # *note* not using concurrent access protection,
    # assumes all handlers/enviroments are registered
    # before first dispatch occurs
    handler     = handler_for(rjr_method)
    environment = env_for(rjr_method)

    return Result.method_not_found(rjr_method) if handler.nil?

    request = Request.new args.merge(:rjr_handler  => handler)

    # set request environment
    request.extend(environment) unless environment.nil?

    begin
      retval = request.handle
      request.result  = Result.new(:result => retval)

    rescue Exception => e
      warning = "Exception Raised in #{rjr_method} handler #{e}"
      RJR::Logger.warn [warning] + e.backtrace

      request.result = Result.new(:error_code  => -32000,
                                  :error_msg   => e.to_s,
                                  :error_class => e.class)
    end

    store_request request
    return request.result
  end

  # Handle responses received from rjr requests. (used internally by nodes)
  #
  # Returns return-value of method handler or raises error
  def handle_response(result)
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
