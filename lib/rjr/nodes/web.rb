# RJR WWW Endpoint
#
# Implements the RJR::Node interface to satisty JSON-RPC requests over the HTTP protocol
#
# The web node does not support callbacks at the moment,
# though would like to look into how to implement this
#
# Copyright (C) 2012-2013 Mohammed Morsi <mo@morsi.org>
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
# TODO output: "em-http-request/evma_httpserver gems could not be loaded, skipping web node definition"
require 'rjr/nodes/missing_node'
RJR::Nodes::Web = RJR::Nodes::Missing

else

require 'thread'
require 'eventmachine'

require 'rjr/node'
require 'rjr/message'

module RJR
module Nodes

# @private
# Helper class intialized by eventmachine encapsulating a http connection
class WebConnection < EventMachine::Connection
  include EventMachine::HttpServer

  # WebConnection initializer.
  #
  # specify the web node establishing the connection
  def initialize(args = {})
    @rjr_node = args[:rjr_node]
  end

  # {EventMachine::Connection#process_http_request} callback, handle request messages
  def process_http_request
    # TODO support http protocols other than POST
    msg = @http_post_content.nil? ? '' : @http_post_content
    @rjr_node.send(:handle_message, msg, self) # XXX private method

    # XXX we still have to send a response back to client to satisfy 
    # the http standard, even if this is a notification. handle_message
    # does not do this.
    @rjr_node.send_msg "", self if NotificationMessage.is_notification_message?(msg)
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
#   # initialize node
#   server = RJR::Nodes::Web.new :node_id => 'server', :host => 'localhost', :port => '7777'
#
#   # register rjr dispatchers (see RJR::Dispatcher)
#   server.dispatcher.handle('hello') do |name|
#     "Hello #{name}!"
#   end
#
#   # listen, and block
#   server.listen
#   server.join
#
# @example Invoking json-rpc requests over http using rjr
#   client = RJR::Nodes::Web.new :node_id => 'client'
#   puts client.invoke('http://localhost:7777', 'hello', 'mo')
#
# @example Invoking json-rpc requests over http using curl
#   $ curl -X POST http://localhost:7777 -d '{"jsonrpc":"2.0","method":"hello","params":["mo"],"id":"123"}'
#   > {"jsonrpc":"2.0","id":"123","result":"Hello mo!"}
#
class Web < RJR::Node

  RJR_NODE_TYPE = :web

  public

  # Web initializer
  # @param [Hash] args the options to create the tcp node with
  # @option args [String] :host the hostname/ip which to listen on
  # @option args [Integer] :port the port which to listen on
  def initialize(args = {})
     super(args)
     @host      = args[:host]
     @port      = args[:port]
  end

  # Send data using specified http connection
  #
  # Implementation of {RJR::Node#send_msg}
  def send_msg(data, connection)
    # we are assuming that since http connections
    # are not persistant, we should be sending a
    # response message here

    resp = EventMachine::DelegatedHttpResponse.new(connection)
    #resp.status  = response.result.success ? 200 : 500
    resp.status = 200
    resp.content = data.to_s
    resp.content_type "application/json"
    resp.send_response
  end

  # Instruct Node to start listening for and dispatching rpc requests
  #
  # Implementation of {RJR::Node#listen}
  def listen
    @em.schedule do
      EventMachine::start_server(@host, @port, WebConnection, :rjr_node => self)
    end
    self
  end

  # Instructs node to send rpc request, and wait for / return response
  #
  # Implementation of {RJR::Node#invoke}
  #
  # Do not invoke directly from em event loop or callback as will block the message
  # subscription used to receive responses
  #
  # @param [String] uri location of node to send request to, should be
  #   in format of http://hostname:port
  # @param [String] rpc_method json-rpc method to invoke on destination
  # @param [Array] args array of arguments to convert to json and invoke remote method wtih
  def invoke(uri, rpc_method, *args)
    message = RequestMessage.new :method => rpc_method,
                                 :args   => args,
                                 :headers => @message_headers
    cb = lambda { |http|
      # TODO handle errors
      handle_message(http.response, http)
    }

    @em.schedule do
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
  # Implementation of {RJR::Node#notify}
  #
  # @param [String] uri location of node to send request to, should be
  #   in format of http://hostname:port
  # @param [String] rpc_method json-rpc method to invoke on destination
  # @param [Array] args array of arguments to convert to json and invoke remote method wtih
  def notify(uri, rpc_method, *args)
    # will block until message is published
    published_l = Mutex.new
    published_c = ConditionVariable.new

    invoked = false
    message = NotificationMessage.new :method => rpc_method,
                                      :args   => args,
                                      :headers => @message_headers
    cb = lambda { |arg| published_l.synchronize { invoked = true ; published_c.signal }}
    @em.schedule do
      http = EventMachine::HttpRequest.new(uri).post :body => message.to_s
      http.errback  &cb
      http.callback &cb
    end
    published_l.synchronize { published_c.wait published_l unless invoked }
    nil
  end
end

end # module Nodes
end # module RJR
end # !skip_module
