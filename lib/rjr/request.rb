# RJR Request Representation
#
# Copyright (C) 2012-2014 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'json'
require 'rjr/common'

module RJR

# JSON-RPC request representation.
#
# Registered request handlers will be invoked in the context of
# instances of this class, meaning all member variables will be available
# for use in the handler.
class Request
  # Result of the request operation, set by dispatcher
  attr_accessor :result

  # Method which request is for
  attr_accessor :rjr_method

  # Arguments be passed to method
  attr_accessor :rjr_method_args

  # Headers which came w/ request
  attr_accessor :rjr_headers

  # Type of node which request came in on
  attr_accessor :rjr_node_type

  # ID of node which request came in on
  attr_accessor :rjr_node_id

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
    @rjr_method_args = args[:rjr_method_args] || args['rjr_method_args'] || []
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
    node_sig   = "#{@rjr_node_id}(#{@rjr_node_type})"
    method_sig = "#{@rjr_method}(#{@rjr_method_args.join(',')})"

    RJR::Logger.info "#{node_sig}->#{method_sig}"

    retval = instance_exec(*@rjr_method_args, &@rjr_handler)

    RJR::Logger.info \
      "#{node_sig}<-#{method_sig}<-#{retval.nil? ? "nil" : retval}"

    return retval
  end

  # Convert request to json representation and return it
  def to_json(*a)
    {
      'json_class' => self.class.name,
      'data'       =>
        {:request => { :rjr_method      => @rjr_method,
                       :rjr_method_args => @rjr_method_args,
                       :rjr_headers     => @rjr_headers,
                       :rjr_node_type   => @rjr_node_type,
                       :rjr_node_id     => @rjr_node_id },

         :result  => { :result          => @result.result,
                       :error_code      => @result.error_code,
                       :error_msg       => @result.error_msg,
                       :error_class     => @result.error_class } }
    }.to_json(*a)
  end

  # Create new request from json representation
  def self.json_create(o)
    result  = Result.new(o['data']['result'])
    request = Request.new(o['data']['request'])
    request.result = result
    return request
  end

end # class Request
end # module RJR
