# RJR Request / Response Dispatcher
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the AGPLv3+ http://www.gnu.org/licenses/agpl.txt

# establish client connection w/ specified args and invoke block w/ 
# newly created client, returning it after block terminates

module RJR

class Result
  attr_accessor :success
  attr_accessor :failed
  attr_accessor :result
  attr_accessor :error_code
  attr_accessor :error_msg

  def initialize(args = {})
    if args.has_key?(:result)
      @success = true
      @failed  = false
      @result  = args[:result]
    elsif args.has_key?(:error_code)
      @success = false
      @failed  = true
      @error_code  = args[:error_code]
      @error_msg   = args[:error_msg]
    end
  end

  def to_s
    "#{@success} #{@result} #{@error_code} #{@error_msg}"
  end
end

class Dispatcher
  # register a handler to the specified method
  def self.add_handler(method, &handler)
    @@handlers  ||= {}
    @@handlers[method] = handler
  end

  # Helper to handle request messages
  def self.dispatch_request(method, args)
     handler = @@handlers[method]
     if handler.nil?
       return Result.new(:error_code => -32602,
                         :error_message => 'Method not found')
     else
       begin
         retval = handler.call(*args)
         return Result.new(:result => retval)
       rescue Exception => e
         return Result.new(:error_code => -32000,
                           :error_msg  => e.to_s)
       end
     end

     return nil
  end

  # Helper to handle response messages
  def self.handle_response(result)
     raise Exception.new(result.error_msg) unless result.success
     return result.result
  end

end

end # module RJR
