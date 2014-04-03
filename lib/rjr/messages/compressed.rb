# RJR Compressed Messages
#
# *Note* this module is still expiremental
#
# Copyright (C) 2014 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

# TODO split up into seperate modules
# (under lib/rjr/messages/compressed/ w/ this file including all)

require 'zlib'
require 'base64'

require 'rjr/messages'

module RJR
module Messages
  # Make backups of original class references
  module Uncompressed
    Request      = RJR::Messages::Request
    Response     = RJR::Messages::Response
    Notification = RJR::Messages::Notification
  end

  # Subclass original message classes w/ versions that first
  #   check for compressed messages before dispatching to superclass
  module Compressed
    class Request < Uncompressed::Request
      COMPRESSED = true

      def initialize(args = {})
        parse_args(args)
      end

      private

      def parse_args(args)
        args = Hash[args]
        if args[:message]
          message = args.delete(:message)
          parse_message(message, args)
        else
          super(args)
        end
      end

      def parse_message(message, args={})
        @json_message = message
        request       = JSONParser.parse(@json_message)

        if request.has_key?('m')
          decoded   = Base64.decode64(request['p'])
          inflated  = Zlib::Inflate.inflate(decoded)
          converted = JSONParser.parse(inflated)

          parse_args({:method => request['m'],
                      :id     => request['i'],
                      :args   => converted}.merge(args))

        else
          parse_args({:method => request['method'],
                      :args   => request['params'],
                      :id     => request['id']}.merge(args))
        end
      end

      public

      def self.is_compressed_request_message?(message)
        begin
           parsed = JSONParser.parse(message)
           parsed.has_key?('m') && parsed.has_key?('i')
        rescue Exception => e
          false
        end
      end

      def self.is_request_message?(message)
        is_compressed_request_message?(message) || super(message)
      end

      def to_json(*a)
        deflated = Zlib::Deflate.deflate(@jr_args.to_json.to_s)
        encoded  = Base64.encode64(deflated)

        {'j' => 2.0,
         'i' => @msg_id,
         'm' => @jr_method,
         'p' => encoded}.merge(@headers).to_json(*a)
      end
    end

    class Response < Uncompressed::Response
      def initialize(args = {})
        parse_args(args)
      end

      private

      def parse_args(args)
        args = Hash[args]
        @request = args[:request]

        if args[:message]
          message = args.delete(:message)
          parse_message(message, args)
        else
          super(args)
        end
      end

      def parse_message(message, args={})
        @json_message = message
        response      = JSONParser.parse(@json_message)

        if response.has_key?('r') || response.has_key?('e')
          result = parse_compressed_result(response)
          parse_args({:id     => response['i'],
                      :result => result}.merge(args))

        else
          result = parse_result(response)
          parse_args({:id     => response['id'],
                      :result => result}.merge(args))
        end
      end

      def parse_compressed_result(response)
        @result         = Result.new
        @result.success = response.has_key?('r')
        @result.failed  = !@result.success

        if @result.success
          decoded   = Base64.decode64(response['r'])
          inflated  = Zlib::Inflate.inflate(decoded)
          converted = JSONParser.parse(inflated).first
          @result.result = converted

        elsif response.has_key?('e')
          @result.error_code  = response['e']['co']
          @result.error_msg   = response['e']['m']
          @result.error_class = response['e']['cl']
        end

        @result
      end

      public

      def has_compressed_request?
        !!@request && @request.class.const_defined?(:COMPRESSED)
      end

      def has_uncompressed_request?
        !!@request && !@request.class.const_defined?(:COMPRESSED)
      end

      def self.is_compressed_response_message?(message)
        begin
          json = JSONParser.parse(message)
          json.has_key?('r') || json.has_key?('e')
        rescue Exception => e
          puts e.to_s
          false
        end
      end

      def self.is_response_message?(message)
        is_compressed_response_message?(message) || super(message)
      end

      def compressed_success_json
        # XXX encapsulate in array & extract above so as to
        # guarantee to be able to be parsable JSON
        deflated = Zlib::Deflate.deflate([@result.result].to_json.to_s)
        encoded  = Base64.encode64(deflated)
        {'r' => encoded}
      end

      def compressed_error_json
        {'e' => {'co' => @result.error_code,
                 'm'  => @result.error_msg,
                 'cl' => @result.error_class}}
      end

      def to_json(*a)
        return super(*a) if has_uncompressed_request?

        result_json = @result.success ?
                      compressed_success_json : compressed_error_json

        response = {'j' => 2.0,
                    'i' => @msg_id}.merge(@headers).
                                    merge(result_json).to_json(*a)
      end
    end

    class Notification < Uncompressed::Notification
      def initialize(args = {})
        parse_args(args)
      end

      private

      def parse_args(args)
        args = Hash[args]
        if args[:message]
          message = args.delete(:message)
          parse_message(message, args)
        else
          super(args)
        end
      end

      def parse_message(message, args={})
        @json_message = message
        request       = JSONParser.parse(@json_message)

        if request.has_key?('m')
          decoded   = Base64.decode64(request['p'])
          inflated  = Zlib::Inflate.inflate(decoded)
          converted = JSONParser.parse(inflated)
          parse_args({:method => request['m'],
                      :args   => converted}.merge(args))

        else
          parse_args({:method => request['method'],
                      :args   => request['params']}.merge(args))
        end
      end

      public

      def self.is_compressed_notification_message?(message)
        begin
           parsed = JSONParser.parse(message)
           parsed.has_key?('m') && !parsed.has_key?('i')
        rescue Exception => e
          false
        end
      end

      def self.is_notification_message?(message)
        is_compressed_notification_message?(message) || super(message)
      end

      def to_json(*a)
        deflated = Zlib::Deflate.deflate(@jr_args.to_json.to_s)
        encoded  = Base64.encode64(deflated)

        {'j' => 2.0,
         'm' => @jr_method,
         'p' => encoded}.merge(@headers).to_json(*a)
      end
    end
  end

  # Override original classes w/ subclasses
  Request      = Compressed::Request
  Response     = Compressed::Response
  Notification = Compressed::Notification

end # module Messages
end # module RJR
