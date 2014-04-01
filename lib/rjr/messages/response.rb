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
  # This should be invoked with one of two argument sets. If creating a new message
  # to send to the client, specify :id, :result, and :headers to include in the message.
  # If handling an new request message sent from the client, simply specify :message
  # and optionally any additional headers (they will be merged with the headers contained
  # in the message)
  #
  # @param [Hash] args options to set on request
  # @option args [String] :message json string received from sender
  # @option args [Hash] :headers optional headers to set in request and subsequent messages
  # @option args [String] :id id to set in response message, should be same as that in received message
  # @option args [RJR::Result] :result result of json-rpc method invocation
  def initialize(args = {})
    if args.has_key?(:message)
      @json_message  = args[:message]
      response = JSONParser.parse(@json_message)
      @msg_id  = response['id']
      @result   = Result.new
      @result.success   = response.has_key?('result')
      @result.failed    = !response.has_key?('result')
      @headers   = args.has_key?(:headers) ? {}.merge!(args[:headers]) : {}

      if @result.success
        @result.result = response['result']

      elsif response.has_key?('error')
        @result.error_code = response['error']['code']
        @result.error_msg  = response['error']['message']
        @result.error_class = response['error']['class']  # TODO safely constantize this ?

      end

      response.keys.select { |k|
        !['jsonrpc', 'id', 'result', 'error'].include?(k)
      }.each { |k| @headers[k] = response[k] }

    elsif args.has_key?(:result)
      @msg_id  = args[:id]
      @result  = args[:result]
      @headers = args[:headers]

    #else
    #  raise ArgumentError, "must specify :message or :result"

    end

  end

  # Class helper to determine if the specified string is a valid json-rpc
  # method response
  # @param [String] message string message to check
  # @return [true,false] indicating if message is response message
  def self.is_response_message?(message)
    begin
      json = JSONParser.parse(message)
      json.has_key?('result') || json.has_key?('error')
    rescue Exception => e
      # FIXME log error
      puts e.to_s
      false
    end
  end

  # Convert request message to string json format
  def to_s
    s = ''
    if result.success
      s =    {'jsonrpc' => '2.0',
              'id'      => @msg_id,
              'result'  => @result.result}

    else
      s =    {'jsonrpc' => '2.0',
              'id'      => @msg_id,
              'error'   => { 'code'    => @result.error_code,
                             'message' => @result.error_msg,
                             'class'   => @result.error_class}}
    end

    s.merge! @headers unless headers.nil?
    return s.to_json.to_s
  end

end # class Response
end # module Messages
end # module RJR
