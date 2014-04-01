# RJR Result Representation
#
# Copyright (C) 2012-2014 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

module RJR

# JSON-RPC Result Representation
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

end # class Result
end # module RJR
