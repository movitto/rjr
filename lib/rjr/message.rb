# RJR Message
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the AGPLv3+ http://www.gnu.org/licenses/agpl.txt

# establish client connection w/ specified args and invoke block w/ 
# newly created client, returning it after block terminates

require 'json'

module RJR

class RequestMessage
  # Helper method to generate a random id
  def self.gen_uuid
    ["%02x"*4, "%02x"*2, "%02x"*2, "%02x"*2, "%02x"*6].join("-") %
        Array.new(16) {|x| rand(0xff) }
  end

  attr_accessor :jr_method
  attr_accessor :jr_args
  attr_accessor :msg_id

  def initialize(args = {})
    if args.has_key?(:message)
      request = JSON.parse(args[:message])
      @jr_method = request['method']
      @jr_args   = request['params']
      @msg_id    = request['id']
    elsif args.has_key?(:method)
      @jr_method = args[:method]
      @jr_args   = args[:args]
      @msg_id    = RequestMessage.gen_uuid
    end
  end

  def to_s
    request = { 'jsonrc' => '2.0',
                'method' => @jr_method,
                'params' => @jr_args }
    request['id'] = @msg_id unless @msg_id.nil?
    request.to_json.to_s
  end
end

class ResponseMessage
  attr_accessor :msg_id
  attr_accessor :result

  def initialize(args = {})
    if args.has_key?(:message)
      response = JSON.parse(args[:message])
      @msg_id  = response['id']
      @result   = Result.new
      @result.success   = response.has_key?('result')
      @result.failed    = !response.has_key?('result')
      if @result.success
        @result.result = response['result']
      else
        @result.error_code = response['error']['code']
        @result.error_msg  = response['error']['message']
      end
    elsif args.has_key?(:result)
      @msg_id = args[:id]
      @result = args[:result]
    end
  end

  def to_s
    if result.success
      return {'jsonrpc' => '2.0',
              'id'      => @msg_id,
              'result'  => @result.result}.to_json.to_s
    else
      return {'jsonrpc' => '2.0',
              'id'      => @msg_id,
              'error'   => { 'code'    => @result.error_code,
                             'message' => @result.error_msg }}.to_json.to_s
    end
  end
end
end
