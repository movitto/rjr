# RJR Request / Response Dispatcher
#
# Representation of a json-rpc request, response and mechanisms which to
# register methods to handle requests and return responses
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'rjr/common'
require 'json'

module RJR

# JSON-RPC result representation
class Result
  # Boolean indicating if request was successfully invoked
  attr_accessor :success

  # Boolean indicating if request failed in some manner
  attr_accessor :failed

  # Return value of the json-rpc call if successful
  attr_accessor :result

  # Code corresponding to json-rpc error if problem occured during request invocation
  attr_accessor :error_code

  # Message corresponding to json-rpc error if problem occured during request invocation
  attr_accessor :error_msg

  # Class of error raised (if any) during request invocation (this is extra metadata beyond standard json-rpc)
  attr_accessor :error_class

  # RJR result intializer
  # @param [Hash] args options to set on result
  # @option args [Object] :result result of json-rpc method handler if successfully returned
  # @option args [Integer] :error_code code corresponding to json-rpc error if problem occured during request invocation
  # @option args [String] :error_msg message corresponding to json-rpc error if problem occured during request invocation
  # @option args [Class] :error_class class of error raised (if any) during request invocation (this is extra metadata beyond standard json-rpc)
  def initialize(args = {})
    @result        = args[:result]      || args['result']
    @error_code    = args[:error_code]  || args['error_code']
    @error_msg     = args[:error_msg]   || args['error_msg']
    @error_class   = args[:error_class] || args['error_class']

    @success       =  @error_code.nil?
    @failed        = !@error_code.nil?
  end

  # Compare Result against other result, returning true if both correspond
  # to equivalent json-rpc results else false
  def ==(other)
    @success     == other.success    &&
    @failed      == other.failed     &&
    @result      == other.result     &&
    @error_code  == other.error_code &&
    @error_msg   == other.error_msg  &&
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

# JSON-RPC request representation.
#
# Registered request handlers will be invoked in the context of
# instances of this class, meaning all member variables will be available
# for use in the handler.
class Request
  # Result of the request operation, set by dispatcher
  attr_accessor :result

  # RJR Request initializer
  # @param [Hash] args options to set on request
  # @option args [String] :rjr_method name of the method which request is for
  # @option args [Array]  :rjr_method_args array of arguments which to pass to the rpc method handler
  # @option args [Hash]   :rjr_headers hash of keys/values corresponding to optional headers received as part of of the request
  # @option args [String] :rjr_client_ip ip address of client which invoked the request (if applicable)
  # @option args [String] :rjr_client_port port of client which invoked the request (if applicable)
  # @option args [RJR::Callback] :rjr_callback callback through which requests/notifications can be sent to remote node
  # @option args [RJR::Node] :rjr_node rjr node which request was received on
  # @option args [String] :rjr_node_id id of the rjr node which request was received on
  # @option args [Symbol] :rjr_node_type type of the rjr node which request was received on
  # @option args [Callable] :rjr_handler callable object registered to the specified method which to invoke request on with arguments
  def initialize(args = {})
    @rjr_method      = args[:rjr_method]      || args['rjr_method']
    @rjr_method_args = args[:rjr_method_args] || args['rjr_method_args']
    @rjr_headers     = args[:rjr_headers]     || args['rjr_headers']

    @rjr_client_ip   = args[:rjr_client_ip]
    @rjr_client_port = args[:rjr_client_port]

    @rjr_callback    = args[:rjr_callback]
    @rjr_node        = args[:rjr_node]
    @rjr_node_id     = args[:rjr_node_id]     || args['rjr_node_id']
    @rjr_node_type   = args[:rjr_node_type]   || args['rjr_node_type']

    @rjr_handler     = args[:rjr_handler]

    @result = nil
  end

  # Invoke the request by calling the registered handler with the registered
  # method parameters in the local scope
  def handle
    RJR::Logger.info "Dispatching '#{@rjr_method}' request with parameters (#{@rjr_method_args.join(',')}) on #{@rjr_node_type}-node(#{@rjr_node_id})"
    retval = instance_exec(*@rjr_method_args, &@rjr_handler)
    RJR::Logger.info "#{@rjr_method} request with parameters (#{@rjr_method_args.join(',')}) returning #{retval}"
    return retval
  end

  # Convert request to json representation and return it
  def to_json(*a)
    {
      'json_class' => self.class.name,
      'data'       =>
        {:request => { :rjr_method      => request.rjr_method,
                       :rjr_method_args => request.rjr_method_args,
                       :rjr_headers     => request.rjr_headers,
                       :rjr_node_type   => request.rjr_node_type,
                       :rjr_node_id     => request.rjr_node_id },

         :result  => { :result          => result.result,
                       :error_code      => result.error_code,
                       :error_msg       => result.error_msg,
                       :error_class     => result.error_class } }
    }.to_json(*a)
  end

  # Create new request from json representation
  def self.json_create(o)
    result  = Result.new(o['data']['result'])
    request = Request.new(o['data']['request'])
    request.result = result
    return request
  end

end

# Primary RJR JSON-RPC method dispatcher interface.
#
# Provides class methods which to register global handlers to json-rpc methods and
# to handle requests and responses.
class Dispatcher
  # Registered json-rpc request signatures and corresponding handlers
  attr_reader :handlers

  # Requests which have been dispatched
  def requests ; @requests_lock.synchronize { Array.new(@requests) } ; end

  # RJR::Dispatcher intializer
  def initialize
    @handlers = Hash.new()

    @requests_lock = Mutex.new
    @requests = []
  end

  # Register json-rpc handler with dispatcher
  #
  # @param [String] signature request signature to match
  # @param [Callable] callable callable object which to bind to signature
  # @param [Callable] &bl block parameter will be set to callback if specified
  def handle(signature, callback = nil, &bl)
    @handlers[signature] = callback unless callback.nil?
    @handlers[signature] = bl       unless bl.nil?
    self
  end

  # Dispatch received request. (used internally by nodes)
  def dispatch(args = {})
     # currently we just match method name against signature
     # TODO if signature if a regex, match against method name
     #      or if callable, invoke it w/ request checking boolean return value for match
     # TODO not using concurrent access portection, assumes all handlers are registered
     #      before first dispatch occurs
     handler = @handlers[args[:rjr_method]]

     return Result.method_not_found(args[:rjr_method]) if handler.nil?

     # TODO compare arity of handler to number of method_args passed in
     request = Request.new args.merge(:rjr_handler  => handler)

     begin
       retval  = request.handle
       request.result  = Result.new(:result => retval)

     rescue Exception => e
       RJR::Logger.warn ["Exception Raised in #{args[:rjr_method]} handler #{e}"] +
                         e.backtrace
       request.result =
         Result.new(:error_code => -32000,
                    :error_msg  => e.to_s,
                    :error_class => e.class)

     end

     @requests_lock.synchronize { @requests << request }
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
