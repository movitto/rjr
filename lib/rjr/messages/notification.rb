# RJR Notification Message
#
# Copyright (C) 2012-2014 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'json'
require 'rjr/util/json_parser'

module RJR
module Messages

# Message sent to a JSON-RPC server to invoke a rpc method but
# indicate the result should _not_ be returned
class Notification
  # Message string received from the source
  attr_accessor :message

  # Method source is invoking on the destination
  attr_accessor :jr_method

  # Arguments source is passing to destination method
  attr_accessor :jr_args

  # Optional headers to add to json outside of standard json-rpc request
  attr_accessor :headers

  # RJR Notification Message initializer
  #
  # No message id will be generated in accordance w/ the jsonrpc standard
  #
  # @param [Hash] args options to set on request
  # @option args [String] :message json string received from sender
  # @option args [Hash] :headers optional headers to set in request and subsequent messages
  # @option args [String] :method method to invoke on server
  # @option args [Array<Object>] :args to pass to server method, all must be convertable to/from json
  def initialize(args = {})
    parse_args(args)
  end

  private

  def parse_args(args)
    @jr_method = args[:method]
    @jr_args   = args[:args]    || []
    @headers   = args[:headers] || {}

    parse_message(args[:message]) if args.has_key?(:message)
  end

  def parse_message(message)
    @message   = message
    @jr_method = message['method']
    @jr_args   = message['params']

    parse_headers(message)
  end

  def parse_headers(message)
    message.keys.select { |k|
      !['jsonrpc', 'method', 'params'].include?(k)
    }.each { |k| @headers[k] = message[k] }
  end

  public

  # Class helper to determine if the specified string is a valid json-rpc
  # notification
  #
  # @param [String] message string message to check
  # @return [true,false] indicating if message is a notification message
  def self.is_notification_message?(message)
    message.has?('method') && !message.has?('id')
  end

  # Convert notification message to json
  def to_json(*a)
    {'jsonrpc' => '2.0',
     'method'  => @jr_method,
     'params'  => @jr_args}.merge(@headers).to_json(*a)
  end

  # Convert request to string format
  def to_s
    to_json.to_s
  end
end # class Notification
end # module Messages
end # module RJR
