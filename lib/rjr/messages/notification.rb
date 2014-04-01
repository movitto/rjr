# RJR Notification Message
#
# Copyright (C) 2012-2014 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'json'
require 'rjr/json_parser'

module RJR
module Messages

# Message sent to a JSON-RPC server to invoke a rpc method but
# indicate the result should _not_ be returned
class Notification
  # Message string received from the source
  attr_accessor :json_message

  # Method source is invoking on the destination
  attr_accessor :jr_method

  # Arguments source is passing to destination method
  attr_accessor :jr_args

  # Optional headers to add to json outside of standard json-rpc request
  attr_accessor :headers

  # RJR Notification Message initializer
  #
  # This should be invoked with one of two argument sets. If creating a new message
  # to send to the server, specify :method, :args, and :headers to include in the message
  # If handling an new request message sent from the client, simply specify :message and
  # optionally any additional headers (they will be merged with the headers contained in
  # the message)
  # 
  # No message id will be generated in accordance w/ the jsonrpc standard
  #
  # @param [Hash] args options to set on request
  # @option args [String] :message json string received from sender
  # @option args [Hash] :headers optional headers to set in request and subsequent messages
  # @option args [String] :method method to invoke on server
  # @option args [Array<Object>] :args to pass to server method, all must be convertable to/from json
  def initialize(args = {})
    if args.has_key?(:message)
      begin
        @json_message = args[:message]
        notification = JSONParser.parse(@json_message)
        @jr_method = notification['method']
        @jr_args   = notification['params']
        @headers   = args.has_key?(:headers) ? {}.merge!(args[:headers]) : {}

        notification.keys.select { |k|
          !['jsonrpc', 'method', 'params'].include?(k)
        }.each { |k| @headers[k] = notification[k] }

      rescue Exception => e
        #puts "Exception Parsing Notification #{e}"
        raise e
      end

    elsif args.has_key?(:method)
      @jr_method = args[:method]
      @jr_args   = args[:args]
      @headers   = args[:headers]

    end
  end

  # Class helper to determine if the specified string is a valid json-rpc
  # notification
  #
  # @param [String] message string message to check
  # @return [true,false] indicating if message is a notification message
  def self.is_notification_message?(message)
    begin
       # FIXME log error
       parsed = JSONParser.parse(message)
       parsed.has_key?('method') && !parsed.has_key?('id')
    rescue Exception => e
      false
    end
  end

  # Convert notification message to string json format
  def to_s
    notification = { 'jsonrpc' => '2.0',
                     'method' => @jr_method,
                     'params' => @jr_args }
    notification.merge!(@headers) unless @headers.nil?
    notification.to_json.to_s
  end

end # class Notification
end # module Messages
end # module RJR
