# RJR Message
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the AGPLv3+ http://www.gnu.org/licenses/agpl.txt

# establish client connection w/ specified args and invoke block w/ 
# newly created client, returning it after block terminates

require 'json'

module RJR

# Message sent from client to server to invoke a json-rpc method
class RequestMessage
  # Helper method to generate a random id
  def self.gen_uuid
    ["%02x"*4, "%02x"*2, "%02x"*2, "%02x"*2, "%02x"*6].join("-") %
        Array.new(16) {|x| rand(0xff) }
  end

  attr_accessor :json_message
  attr_accessor :jr_method
  attr_accessor :jr_args
  attr_accessor :msg_id
  attr_accessor :headers

  def initialize(args = {})
    if args.has_key?(:message)
      begin
        request = JSON.parse(args[:message])
        @json_message = args[:message]
        @jr_method = request['method']
        @jr_args   = request['params']
        @msg_id    = request['id']
        @headers   = args.has_key?(:headers) ? {}.merge!(args[:headers]) : {}

        request.keys.select { |k|
          !['jsonrpc', 'id', 'method', 'params'].include?(k)
        }.each { |k| @headers[k] = request[k] }

      rescue Exception => e
        #puts "Exception Parsing Request #{e}"
        # TODO
        raise e
      end

    elsif args.has_key?(:method)
      @jr_method = args[:method]
      @jr_args   = args[:args]
      @headers   = args[:headers]
      @msg_id    = RequestMessage.gen_uuid

    end
  end

  def self.is_request_message?(message)
    begin
       JSON.parse(message).has_key?('method')
    rescue Exception => e
      false
    end
  end

  def to_s
    request = { 'jsonrpc' => '2.0',
                'method' => @jr_method,
                'params' => @jr_args }
    request['id'] = @msg_id unless @msg_id.nil?
    request.merge!(@headers) unless @headers.nil?
    request.to_json.to_s
  end

end

# Message sent from server to client in response to request message
class ResponseMessage
  attr_accessor :json_message
  attr_accessor :msg_id
  attr_accessor :result
  attr_accessor :headers

  def initialize(args = {})
    if args.has_key?(:message)
      response = JSON.parse(args[:message])
      @json_message  = args[:message]
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

  def self.is_response_message?(message)
    begin
      JSON.parse(message).has_key?('result')
    rescue Exception => e
      false
    end
  end

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
                             'message' => @result.error_msg }}
    end

    s.merge! @headers unless headers.nil?
    return s.to_json.to_s
  end
end

end
