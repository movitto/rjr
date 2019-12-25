# RJR Request Representation
#
# Copyright (C) 2012-2014 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'json'
require 'rjr/result'
require 'rjr/core_ext'
require 'rjr/util/args'
require 'rjr/util/logger'

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

  # Argument object encapsulating arguments
  attr_accessor :rjr_args

  # Headers which came w/ request
  attr_accessor :rjr_headers

  # Client IP which request came in on (only for direct nodes)
  attr_accessor :rjr_client_ip

  # Port which request came in on (only for direct nodes)
  attr_accessor :rjr_client_port

  # RJR callback which may be used to push data to client
  attr_accessor :rjr_callback

  # Node which the request came in on
  attr_accessor :rjr_node

  # Type of node which request came in on
  attr_accessor :rjr_node_type

  # ID of node which request came in on
  attr_accessor :rjr_node_id

  # Environment handler will be run in
  attr_accessor :rjr_env

  # Actual proc registered to handle request
  attr_accessor :rjr_handler

  # RJR Request initializer
  #
  # @param [Hash] args options to set on request,
  #   see Request accessors for valid keys
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

    @rjr_args        = Arguments.new :args => @rjr_method_args
    @rjr_env         = nil
    @result          = nil
  end

  # Set the environment by extending Request instance with the specified module
  def set_env(env)
    @rjr_env = env
    self.extend(env)
  end

  # Invoke the request by calling the registered handler with the registered
  # method parameters in the local scope
  def handle
    node_sig   = "#{@rjr_node_id}(#{@rjr_node_type})"
    method_sig = "#{@rjr_method}(#{@rjr_method_args})"

    RJR::Logger.info "#{node_sig}->#{method_sig}"

    # TODO option to compare arity of handler to number
    # of method_args passed in ?
    retval = instance_exec(@rjr_method_args, &@rjr_handler)

    RJR::Logger.info \
      "#{node_sig}<-#{method_sig}<-#{retval.nil? ? "nil" : retval}"

    return retval
  end

  def request_json
    {:request => { :rjr_method      => @rjr_method,
                   :rjr_method_args => @rjr_method_args,
                   :rjr_headers     => @rjr_headers,
                   :rjr_node_type   => @rjr_node_type,
                   :rjr_node_id     => @rjr_node_id }}
  end

  def result_json
    return {} unless !!@result
    {:result  => { :result          => @result.result,
                   :error_code      => @result.error_code,
                   :error_msg       => @result.error_msg,
                   :error_class     => @result.error_class }}
  end

  # Convert request to json representation and return it
  def to_json(*a)
    {'json_class' => self.class.name,
     'data'       => request_json.merge(result_json)}.to_json(*a)
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
