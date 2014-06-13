# RJR Request Message
#
# Copyright (C) 2012-2014 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'json'
require 'rjr/util/json_parser'

module RJR
module Messages

# Message sent from client to server to invoke a JSON-RPC method
class Request
  # Message string received from the source
  attr_accessor :message

  # Method source is invoking on the destination
  attr_accessor :jr_method

  # Arguments source is passing to destination method
  attr_accessor :jr_args

  # ID of the message in accordance w/ json-rpc specification
  attr_accessor :msg_id

  # Optional headers to add to json outside of standard json-rpc request
  attr_accessor :headers

  # RJR Request Message initializer
  #
  # @param [Hash] args options to set on request
  # @option args [String] :message json string received from sender
  # @option args [Hash] :headers optional headers to set in request
  #   and subsequent messages
  # @option args [String] :method method to invoke on server
  # @option args [Array<Object>] :args to pass to server method, all
  #   must be convertable to/from json
  def initialize(args = {})
    parse_args(args)
  end

  private

  def parse_args(args)
    @jr_method = args[:method]
    @jr_args   = args[:args]    || []
    @headers   = args[:headers] || {}
    @msg_id    = args[:id]      || gen_uuid

    parse_message(args[:message]) if args.has_key?(:message)
  end

  def parse_message(message)
    @message      = message
    @jr_method    = message['method']
    @jr_args      = message['params']
    @msg_id       = message['id']

    parse_headers(message)
  end

  def parse_headers(message)
    message.keys.select { |k|
      !['jsonrpc', 'id', 'method', 'params'].include?(k)
    }.each { |k| @headers[k] = message[k] }
  end

  public

  # Class helper to determine if the specified message is a valid
  # json-rpc method request message.
  #
  # @param [Message] message to check
  # @return [true,false] indicating if message is request message
  def self.is_request_message?(message)
     message.has?('method') && message.has?('id')
  end

  # Convert request message to json
  def to_json(*a)
    {'jsonrpc' => '2.0',
     'id'      => @msg_id,
     'method'  => @jr_method,
     'params'  => @jr_args}.merge(@headers).to_json(*a)
  end

  # Convert request to string format
  def to_s
    to_json.to_s
  end
end # class Request
end # module Messages
end # module RJR
