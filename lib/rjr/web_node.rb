# RJR WWW Endpoint
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the AGPLv3+ http://www.gnu.org/licenses/agpl.txt

# establish client connection w/ specified args and invoke block w/ 
# newly created client, returning it after block terminates

require 'evma_httpserver'
require 'em-http-request'

module RJR

# Web client node callback interface,
# currently does nothing as web connections aren't persistant
class WebNodeCallback
  def initialize()
  end

  def invoke(data)
  end
end

# Web node definition, listen for and invoke json-rpc requests via web requests
class WebRequestHandler < EventMachine::Connection
  include EventMachine::HttpServer

  def initialize(*args)
    @web_node = args[0]
  end

  def handle_request(message)
    msg    = nil
    result = nil
    begin
      msg    = RequestMessage.new(:message => message, :headers => @web_node.message_headers)
      headers = @web_node.message_headers.merge(msg.headers)
      result = Dispatcher.dispatch_request(:method => msg.jr_method,
                                           :method_args => msg.jr_args,
                                           :headers => headers,
                                           :rjr_callback => WebNodeCallback.new())
    rescue JSON::ParserError => e
      result = Result.invalid_request
    end

    msg_id = msg.nil? ? nil : msg.msg_id
    response = ResponseMessage.new(:id => msg_id, :result => result, :headers => headers)

    resp = EventMachine::DelegatedHttpResponse.new(self)
    #resp.status  = response.result.success ? 200 : 500
    resp.status = 200
    resp.content = response.to_s
    resp.content_type "application/json"
    resp.send_response
  end

  def process_http_request
    # TODO support http protocols other than POST
    # TODO should delete handler threads as they complete & should handle timeout
    msg = @http_post_content.nil? ? '' : @http_post_content
    #@thread_pool << ThreadPoolJob.new { handle_request(msg) }
    handle_request(msg)
  end

  #def receive_data(data)
  #  puts "~~~~ #{data}"
  #end
end

class WebNode < RJR::Node
  # initialize the node w/ the specified params
  def initialize(args = {})
     super(args)
     @host      = args[:host]
     @port      = args[:port]
     @response_queue = []
  end

  # Initialize the web subsystem
  def init_node
  end

  # Instruct Node to start listening for and dispatching rpc requests
  def listen
    em_run do
      init_node
      EventMachine::start_server(@host, @port, WebRequestHandler, self)
    end
  end

  # Instructs node to send rpc request, and wait for / return response
  def invoke_request(uri, rpc_method, *args)
    em_run do
      init_node
      message = RequestMessage.new :method => rpc_method,
                                   :args   => args,
                                   :headers => @message_headers

      http = EventMachine::HttpRequest.new(uri).post :body => message.to_s

      # check responses already received for matching id
      @response_queue.each { |response|
        if response.id == message.id
          headers = @message_headers.merge(response.headers)
          return Dispatcher.handle_response(:result => response.result,
                                            :response => response,
                                            :headers => headers)
        end
      }

      #http.errback { }
      http.callback {
        msg    = ResponseMessage.new(:message => http.response.to_s, :headers => @message_headers)
        if msg.msg_id == message.msg_id
          headers = @message_headers.merge(msg.headers)
          return Dispatcher.handle_response(:result   => msg.result,
                                            :response => msg,
                                            :headers  => headers)
        else
          @response_queue << msg
        end
      }
    end
  end
end

end # module RJR
