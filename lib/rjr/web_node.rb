# RJR WWW Endpoint
#
# Implements the RJR::Node interface to satisty JSON-RPC requests over the HTTP protocol
#
# The web node does not support callbacks at the moment, though at some point we may
# allow a client to specify an optional webserver to send callback requests to. (TODO)
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

# establish client connection w/ specified args and invoke block w/ 
# newly created client, returning it after block terminates

require 'curb'

require 'evma_httpserver'
#require 'em-http-request'

require 'rjr/node'
require 'rjr/message'

module RJR

# Web node callback interface, *note* callbacks are not supported on the web
# node and thus this currently does nothing
class WebNodeCallback
  def initialize()
  end

  def invoke(callback_method, *data)
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
    #@thread_pool << ThreadPoolJob.new { handle_request(msg) }
    handle_request(msg)
  end

  private

  # Internal helper, handle request message received
  def handle_request(message)
    msg    = nil
    result = nil
    begin
      client_port, client_ip = Socket.unpack_sockaddr_in(get_peername)
      msg    = RequestMessage.new(:message => message, :headers => @web_node.message_headers)
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

    resp = EventMachine::DelegatedHttpResponse.new(self)
    #resp.status  = response.result.success ? 200 : 500
    resp.status = 200
    resp.content = response.to_s
    resp.content_type "application/json"
    resp.send_response
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
  # Initialize the web subsystem
  def init_node
  end

  # TCPNode initializer
  # @param [Hash] args the options to create the tcp node with
  # @option args [String] :host the hostname/ip which to listen on
  # @option args [Integer] :port the port which to listen on
  def initialize(args = {})
     super(args)
     @host      = args[:host]
     @port      = args[:port]
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
      init_node
      EventMachine::start_server(@host, @port, WebRequestHandler, self)
    end
  end

  # Instructs node to send rpc request, and wait for / return response
  # @param [String] uri location of node to send request to, should be
  #   in format of http://hostname:port
  # @param [String] rpc_method json-rpc method to invoke on destination
  # @param [Array] args array of arguments to convert to json and invoke remote method wtih
  def invoke_request(uri, rpc_method, *args)
    init_node
    message = RequestMessage.new :method => rpc_method,
                                 :args   => args,
                                 :headers => @message_headers
    res = Curl::Easy.http_post uri, message.to_s
    msg    = ResponseMessage.new(:message => res.body_str, :headers => @message_headers)
    headers = @message_headers.merge(msg.headers)
    return Dispatcher.handle_response(msg.result)
  end
end

end # module RJR
