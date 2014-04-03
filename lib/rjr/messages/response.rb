# RJR Response Message
#
# Copyright (C) 2012-2014 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'json'
require 'rjr/result'
require 'rjr/json_parser'

module RJR
module Messages

# Message sent from server to client in response to a JSON-RPC request
class Response
  # Message string received from the source
  attr_accessor :json_message

  # ID of the message in accordance w/ json-rpc specification
  attr_accessor :msg_id

  # Result encapsulated in the response message
  # @see RJR::Result
  attr_accessor :result

  # Optional headers to add to json outside of standard json-rpc request
  attr_accessor :headers

  # ResponseMessage initializer
  #
  # @param [Hash] args options to set on request
  # @option args [String] :message json string received from sender
  # @option args [Hash] :headers optional headers to set in request
  #   and subsequent messages
  # @option args [String] :id id to set in response message, should
  #   be same as that in received message
  # @option args [RJR::Result] :result result of json-rpc method invocation
  def initialize(args = {})
    parse_args(args)
  end

  private

  def parse_args(args)
    @msg_id  = args[:id]
    @result  = args[:result]
    @headers = args[:headers] || {}

    parse_message(args[:message]) if args.has_key?(:message)
  end

  def parse_message(message)
    @json_message = message
    response      = JSONParser.parse(@json_message)
    @msg_id       = response['id']

    parse_result(response)
    parse_headers(response)
  end

  def parse_result(response)
    @result         = Result.new
    @result.success = response.has_key?('result')
    @result.failed  = !@result.success

    if @result.success
      @result.result = response['result']

    elsif response.has_key?('error')
      @result.error_code  = response['error']['code']
      @result.error_msg   = response['error']['message']

      # TODO can we safely constantize this ?
      @result.error_class = response['error']['class']
    end

    @result
  end

  def parse_headers(request)
    request.keys.select { |k|
      !['jsonrpc', 'id', 'method', 'params'].include?(k)
    }.each { |k| @headers[k] = request[k] }
  end

  public

  # Class helper to determine if the specified string is a valid json-rpc
  # method response
  # @param [String] message string message to check
  # @return [true,false] indicating if message is response message
  def self.is_response_message?(message)
    begin
      # FIXME log error
      json = JSONParser.parse(message)
      json.has_key?('result') || json.has_key?('error')
    rescue Exception => e
      puts e.to_s
      false
    end
  end

  def success_json
    {'result' => @result.result}
  end

  def error_json
    {'error' => {'code'    => @result.error_code,
                 'message' => @result.error_msg,
                 'class'   => @result.error_class}}
  end

  # Convert request message to json
  def to_json(*a)
    result_json = @result.success ? success_json : error_json

    {'jsonrpc' => '2.0',
     'id'      => @msg_id}.merge(@headers).
                           merge(result_json).to_json(*a)
  end

  # Convert request to string format
  def to_s
    to_json.to_s
  end

end # class Response
end # module Messages
end # module RJR
