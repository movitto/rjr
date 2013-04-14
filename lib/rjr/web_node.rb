# RJR WWW Endpoint
#
# Implements the RJR::Node interface to satisty JSON-RPC requests over the HTTP protocol
#
# The web node does not support callbacks at the moment, though at some point we may
# allow a client to specify an optional webserver to send callback requests to. (TODO)
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

skip_module = false
begin
require 'evma_httpserver'
require 'em-http-request'
# TODO also support fallback clients ? (curb / net/http / etc)
rescue LoadError
  skip_module = true
end

if skip_module
# TODO output: "curb/evma_httpserver gems could not be loaded, skipping web node definition"
require 'rjr/missing_node'
RJR::WebNode = RJR::MissingNode

else
require 'socket'

require 'rjr/node'
require 'rjr/message'
require 'rjr/dispatcher'
require 'rjr/thread_pool2'

module RJR

# Web node callback interface, *note* callbacks are not supported on the web
# node and thus this currently does nothing
class WebNodeCallback
  def initialize()
  end

  def invoke(callback_method, *data)
    # TODO throw error?
  end
end

# @private
# Helper class intialized by eventmachine encapsulating a http connection
class WebRequestHandler < EventMachine::Connection
  include EventMachine::HttpServer

  RJR_NODE_TYPE = :web

  # WebRequestHandler initializer.
  #
  # specify the WebNode establishing the connection
  def initialize(*args)
    @web_node = args[0]
  end

  # {EventMachine::Connection#process_http_request} callback, handle request messages
  def process_http_request
    # TODO support http protocols other than POST
    msg = @http_post_content.nil? ? '' : @http_post_content
    ThreadPool2Manager << ThreadPool2Job.new(msg) { |m| handle_request(m) }
  end

  private

  # Internal helper, handle request message received
  def handle_request(message)
    msg    = nil
    result = nil
    notification = NotificationMessage.is_notification_message?(msg)

    begin
      client_port, client_ip = Socket.unpack_sockaddr_in(get_peername)
      msg    = notification ? NotificationMessage.new(:message => message, :headers => @web_node.message_headers) :
                              RequestMessage.new(:message => message, :headers => @web_node.message_headers)
      headers = @web_node.message_headers.merge(msg.headers)
      result = Dispatcher.dispatch_request(msg.jr_method,
                                           :method_args => msg.jr_args,
                                           :headers => headers,
                                           :client_ip => client_ip,
                                           :client_port => client_port,
                                           :rjr_node      => @web_node,
                                           :rjr_node_id   => @web_node.node_id,
                                           :rjr_node_type => RJR_NODE_TYPE,
                                           :rjr_callback => WebNodeCallback.new())
    rescue JSON::ParserError => e
      result = Result.invalid_request
    end

    msg_id = msg.nil? ? nil : msg.msg_id
    response = ResponseMessage.new(:id => msg_id, :result => result, :headers => headers)

    unless notification
      resp = EventMachine::DelegatedHttpResponse.new(self)
      #resp.status  = response.result.success ? 200 : 500
      resp.status = 200
      resp.content = response.to_s
      resp.content_type "application/json"
      resp.send_response
    end
  end
end

# Web node definition, listen for and invoke json-rpc requests via web requests
#
# Clients should specify the hostname / port when listening for requests and
# when invoking them.
#
# *note* the RJR javascript client also supports sending / receiving json-rpc
# messages over http
#
# @example Listening for json-rpc requests over tcp
#   # register rjr dispatchers (see RJR::Dispatcher)
#   RJR::Dispatcher.add_handler('hello') { |name|
#     "Hello #{name}!"
#   }
#
#   # initialize node, listen, and block
#   server = RJR::WebNode.new :node_id => 'server', :host => 'localhost', :port => '7777'
#   server.listen
#   server.join
#
# @example Invoking json-rpc requests over http using rjr
#   client = RJR::WebNode.new :node_id => 'client'
#   puts client.invoke_request('http://localhost:7777', 'hello', 'mo')
#
# @example Invoking json-rpc requests over http using curl
#   $ curl -X POST http://localhost:7777 -d '{"jsonrpc":"2.0","method":"hello","params":["mo"],"id":"123"}'
#   > {"jsonrpc":"2.0","id":"123","result":"Hello mo!"}
#
class WebNode < RJR::Node
  private

  # Internal helper, handle response message received
  def handle_response(http)
    msg    = ResponseMessage.new(:message => http.response, :headers => @message_headers)
    res = err = nil
    begin
      res = Dispatcher.handle_response(msg.result)
    rescue Exception => e
      err = e
    end

    @response_lock.synchronize {
      result = [msg.msg_id, res]
      result << err if !err.nil?
      @responses << result
      @response_cv.signal
    }
  end

  # Internal helper, block until response matching message id is received
  def wait_for_result(message)
    res = nil
    while res.nil?
      @response_lock.synchronize{
        # FIXME throw err if more than 1 match found
        res = @responses.select { |response| message.msg_id == response.first }.first
        if !res.nil?
          @responses.delete(res)

        else
          @response_cv.signal
          @response_cv.wait @response_lock

        end
      }
    end
    return res
  end

  public

  # WebNode initializer
  # @param [Hash] args the options to create the tcp node with
  # @option args [String] :host the hostname/ip which to listen on
  # @option args [Integer] :port the port which to listen on
  def initialize(args = {})
     super(args)
     @host      = args[:host]
     @port      = args[:port]

     @response_lock = Mutex.new
     @response_cv   = ConditionVariable.new
     @responses     = []
  end

  # Register connection event handler,
  #
  # *note* Since web node connections aren't persistant, we don't do anything here.
  # @param [:error, :close] event the event to register the handler for
  # @param [Callable] handler block param to be added to array of handlers that are called when event occurs
  # @yield [LocalNode] self is passed to each registered handler when event occurs
  def on(event, &handler)
    # TODO raise error?
  end

  # Instruct Node to start listening for and dispatching rpc requests
  #
  # Implementation of {RJR::Node#listen}
  def listen
    em_run do
      EventMachine::start_server(@host, @port, WebRequestHandler, self)
    end
  end

  # Instructs node to send rpc request, and wait for / return response
  # @param [String] uri location of node to send request to, should be
  #   in format of http://hostname:port
  # @param [String] rpc_method json-rpc method to invoke on destination
  # @param [Array] args array of arguments to convert to json and invoke remote method wtih
  def invoke_request(uri, rpc_method, *args)
    message = RequestMessage.new :method => rpc_method,
                                 :args   => args,
                                 :headers => @message_headers
    cb = lambda { |http|
      # TODO handle errors
      handle_response(http)
    }

    em_run do
      http = EventMachine::HttpRequest.new(uri).post :body => message.to_s
      http.errback  &cb
      http.callback &cb
    end

    # will block until response message is received
    # TODO optional timeout for response ?
    result = wait_for_result(message)
    if result.size > 2
      raise Exception, result[2]
    end
    return result[1]
  end

  # Instructs node to send rpc notification (immadiately returns / no response is generated)
  #
  # @param [String] uri location of node to send request to, should be
  #   in format of http://hostname:port
  # @param [String] rpc_method json-rpc method to invoke on destination
  # @param [Array] args array of arguments to convert to json and invoke remote method wtih
  def send_notification(uri, rpc_method, *args)
    # will block until message is published
    published_l = Mutex.new
    published_c = ConditionVariable.new

    invoked = false
    message = NotificationMessage.new :method => rpc_method,
                                      :args   => args,
                                      :headers => @message_headers
    cb = lambda { |arg| published_l.synchronize { invoked = true ; published_c.signal }}
    em_run do
      http = EventMachine::HttpRequest.new(uri).post :body => message.to_s
      http.errback  &cb
      http.callback &cb
    end
    published_l.synchronize { published_c.wait published_l unless invoked }
    nil
  end
end

end # module RJR
end
