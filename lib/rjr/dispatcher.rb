# RJR Request / Response Dispatcher
#
# Representation of a json-rpc request, response and mechanisms which to
# register methods to handle requests and return responses
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'rjr/common'

module RJR

# JSON-RPC request representation
class Request
  # name of the method which request is for
  attr_accessor :method

  # array of arguments which to pass to the rpc method handler
  attr_accessor :method_args

  # hash of keys/values corresponding to optional headers received as part of of the request
  attr_accessor :headers

  # callback through which additional requests may be invoked
  attr_accessor :rjr_callback

  # type of the rjr node which request was received on
  attr_accessor :rjr_node_type

  # id of the rjr node which request was received on
  attr_accessor :rjr_node_id

  # callable object registered to the specified method which to invoke request on with arguments
  attr_accessor :handler

  # RJR request intializer
  # @param [Hash] args options to set on request
  # @option args [String] :method name of the method which request is for
  # @option args [Array]  :method_args array of arguments which to pass to the rpc method handler
  # @option args [Hash]   :headers hash of keys/values corresponding to optional headers received as part of of the request
  # @option args [String] :client_ip ip address of client which invoked the request (if applicable)
  # @option args [String] :client_port port of client which invoked the request (if applicable)
  # @option args [RJR::Callback] :rjr_callback callback through which additional requests may be invoked
  # @option args [RJR::Node] :rjr_node rjr node which request was received on
  # @option args [String] :rjr_node_id id of the rjr node which request was received on
  # @option args [Symbol] :rjr_node_type type of the rjr node which request was received on
  # @option args [Callable] :handler callable object registered to the specified method which to invoke request on with arguments
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

  # Actually invoke the request by calling the registered handler with the specified
  # method parameters in the local scope
  def handle
    RJR::Logger.info "Dispatching '#{@method}' request with parameters (#{@method_args.join(',')}) on #{@rjr_node_type}-node(#{@rjr_node_id})"
    retval = instance_exec(*@method_args, &@handler)
    RJR::Logger.info "#{@method} request with parameters (#{@method_args.join(',')}) returning #{retval}"
    return retval
  end
end

# JSON-RPC result representation
class Result
  # boolean indicating if request was successfully invoked
  attr_accessor :success

  # boolean indicating if request was not successfully invoked
  attr_accessor :failed

  # return value of the json-rpc call if successful
  attr_accessor :result

  # code corresponding to json-rpc error if problem occured during request invocation
  attr_accessor :error_code

  # message corresponding to json-rpc error if problem occured during request invocation
  attr_accessor :error_msg

  # class of error raised (if any) during request invocation (this is extra metadata beyond standard json-rpc)
  attr_accessor :error_class

  # RJR result intializer
  # @param [Hash] args options to set on result
  # @option args [Object] :result result of json-rpc method handler if successfully returned
  # @option args [Integer] :error_code code corresponding to json-rpc error if problem occured during request invocation
  # @option args [String] :error_msg message corresponding to json-rpc error if problem occured during request invocation
  # @option args [Class] :error_class class of error raised (if any) during request invocation (this is extra metadata beyond standard json-rpc)
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

  # Compare Result against other result, returning true if both correspond
  # to equivalent json-rpc results else false
  def ==(other)
    @success == other.success &&
    @failed  == other.failed  &&
    @result  == other.result  &&
    @error_code == other.error_code &&
    @error_msg  == other.error_msg  &&
    @error_class == other.error_class
  end

  # Convert Response to human consumable string
  def to_s
    "#{@success} #{@result} #{@error_code} #{@error_msg} #{@error_class}"
  end

  ######### Specific request types

  # JSON-RPC -32600 / Invalid Request
  def self.invalid_request
     return Result.new(:error_code => -32600,
                       :error_msg => '  Invalid Request')
  end

  # JSON-RPC -32602 / Method not found
  def self.method_not_found(name)
     return Result.new(:error_code => -32602,
                       :error_msg => "Method '#{name}' not found")
  end

end

# Association between json-rpc method name and registered handler to
# be invoked on new requests.
#
# When invoked, creates new {RJR::Request} object with specified request
# params and uses it to invoke handler in its context. Formats and returns
# return of operation
class Handler
  attr_accessor :method_name
  attr_accessor :handler_proc

  # RJR::Handler intializer
  # @param [Hash] args options to set on handler
  # @option args [String] :method name of json-rpc method to which handler is bound
  # @option args [Callable] :handle callable object which to bind to method name
  def initialize(args = {})
    @method_name          = args[:method]
    @handler_proc         = args[:handler]
  end

  # Handle new json-rpc request to registered method.
  #
  # Creates new {RJR::Request} with the local method name and handler and the
  # arguments received as part of the request. Uses it to invoke handler and
  # creates and returns new {RJR::Result} encapsulating the return value if
  # successful or error code/message/class if not.
  #
  # If invalid method_name is specified returns a json-rpc 'Method not found'
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

# Primary RJR JSON-RPC method dispatcher interface.
#
# Provides class methods which to register global handlers to json-rpc methods and
# to handle requests and responses.
class Dispatcher
  # Clear all registered json-rpc handlers
  def self.init_handlers
    @@handlers = {}
  end

  # Register a handler for the specified method(s)
  #
  # *WARNING* Do not invoke 'return' in registered handlers as these are blocks and *not* lambdas
  # (see {http://stackoverflow.com/questions/626/when-to-use-lambda-when-to-use-proc-new Ruby Lambdas vs Procs})
  #
  # If specifying a single method name pass in a string, else pass in an array of strings.
  # The block argument will be used as the method handler and will be invoked when
  # json-rpc requests are received corresponding to the method name(s)
  # @param [String,Array<String>] method_names one or more string method names
  # @param [Hash] args options to initialize handler with, current unused
  # @param [Callable] handler block to invoke when json-rpc requests to method are received
  #
  # @example
  #   RJR::Dispatcher.add_handler("hello_world") {
  #     "hello world"
  #   }
  #
  #   RJR::Dispatcher.add_handler(["echo", "ECHO"]) { |val|
  #     val
  #   }
  #
  def self.add_handler(method_names, args = {}, &handler)
    method_names = Array(method_names) unless method_names.is_a?(Array)
    @@handlers  ||= {}
    method_names.each { |method_name|
      @@handlers[method_name] = Handler.new args.merge(:method  => method_name,
                                                       :handler => handler)
    }
  end

  # Helper used by RJR nodes to dispatch requests received via transports to
  # registered handlers.
  def self.dispatch_request(method_name, args = {})
     @@handlers  ||= {}
     handler  = @@handlers[method_name]

     if handler.nil?
       @@generic_handler ||= Handler.new :method => nil
       return @@generic_handler.handle(args.merge(:missing_name => method_name))
     end

     return handler.handle args
  end

  # Helper used by RJR nodes to handle responses received from rjr requests
  #   (returns return-value of method handler or raises error)
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
