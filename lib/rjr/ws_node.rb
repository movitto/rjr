# RJR WebSockets Endpoint
#
# Implements the RJR::Node interface to satisty JSON-RPC requests over the websockets protocol
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

skip_module = false
begin
require 'em-websocket'
require 'em-websocket-client'
rescue LoadError
  skip_module = true
end

if skip_module
# TODO output: "ws dependencies could not be loaded, skipping ws node definition"
require 'rjr/missing_node'
RJR::WSNode = RJR::MissingNode

else
require 'socket'
require 'rjr/node'
require 'rjr/message'
require 'rjr/dispatcher'
require 'rjr/thread_pool2'

module RJR

# Web Socket node callback interface, used to invoke json-rpc methods
# against a remote node via a web socket connection previously established
#
# After a node sends a json-rpc request to another, the either node may send
# additional requests to each other via the socket already established until
# it is closed on either end
class WSNodeCallback
  # WSNodeCallback initializer
  # @param [Hash] args the options to create the websocket node callback with
  # @option args [Socket] :socket socket connection used to send/receive messages
  # @option args [Hash] :headers hash of rjr message headers present in client request when callback is established
  def initialize(args = {})
    @socket    = args[:socket]
    @message_headers = args[:headers]
  end

  # Implementation of {RJR::NodeCallback#invoke}
  def invoke(callback_method, *data)
    msg = NotificationMessage.new :method => callback_method, :args => data, :headers => @message_headers
    raise RJR::Errors::ConnectionError.new("websocket closed") if @socket.state == :closed
    # TODO surround w/ begin/rescue block incase of other socket errors?
    @socket.send(msg.to_s)
  end
end

# Web socket node definition, listen for and invoke json-rpc requests via web sockets
#
# Clients should specify the hostname / port when listening for and invoking requests.
#
# *note* the RJR javascript client also supports sending / receiving json-rpc
# messages over web sockets
#
# @example Listening for json-rpc requests over tcp
#   # register rjr dispatchers (see RJR::Dispatcher)
#   RJR::Dispatcher.add_handler('hello') { |name|
#     "Hello #{name}!"
#   }
#
#   # initialize node, listen, and block
#   server = RJR::WSNode.new :node_id => 'server', :host => 'localhost', :port => '7777'
#   server.listen
#   server.join
#
# @example Invoking json-rpc requests over web sockets using rjr
#   client = RJR::WsNode.new :node_id => 'client'
#   puts client.invoke_request('ws://localhost:7777', 'hello', 'mo')
#
class WSNode < RJR::Node
  RJR_NODE_TYPE = :ws

  private

  # Internal helper initialize new connection
  def init_node(uri, &on_init)
    connection = nil
    @connections_lock.synchronize {
      connection = @connections.find { |c|
                     c.url == uri
                   }
      if connection.nil?
        connection = EventMachine::WebSocketClient.connect(uri)
        connection.callback do
          on_init.call(connection)
        end
        @connections << connection
        # TODO sleep until connected?
      else
        on_init.call(connection)
      end
    }
    connection
  end

  # Internal helper handle messages
  def handle_msg(endpoint, msg)
    # TODO use messageutil incase of large messages?
    if RequestMessage.is_request_message?(msg)
      ThreadPool2Manager << ThreadPool2Job.new { handle_request(endpoint, msg, false) }

    elsif NotificationMessage.is_notification_message?(msg)
      ThreadPool2Manager << ThreadPool2Job.new { handle_request(endpoint, msg, true) }

    elsif ResponseMessage.is_response_message?(msg)
      handle_response(msg)

    end
  end

  # Internal helper, handle request message received
  def handle_request(endpoint, message, notification=false)
    # XXX hack to handle client disconnection (should grap port/ip immediately on connection and use that)
    client_port,client_ip = nil,nil
    begin
      client_port, client_ip = Socket.unpack_sockaddr_in(endpoint.get_peername)
    rescue Exception=>e
    end

    msg    = notification ? NotificationMessage.new(:message => message, :headers => @message_headers) :
                            RequestMessage.new(:message => message, :headers => @message_headers)
    headers = @message_headers.merge(msg.headers)
    result = Dispatcher.dispatch_request(msg.jr_method,
                                         :method_args => msg.jr_args,
                                         :headers => headers,
                                         :client_ip => client_ip,
                                         :client_port => client_port,
                                         :rjr_node      => self,
                                         :rjr_node_id   => @node_id,
                                         :rjr_node_type => RJR_NODE_TYPE,
                                         :rjr_callback =>
                                           WSNodeCallback.new(:socket => endpoint,
                                                              :headers => headers))
    unless notification
      response = ResponseMessage.new(:id => msg.msg_id, :result => result, :headers => headers)
      endpoint.send(response.to_s)
    end
  end

  # Internal helper, handle response message received
  def handle_response(data)
    msg    = ResponseMessage.new(:message => data, :headers => @message_headers)
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
  # WSNode initializer
  # @param [Hash] args the options to create the web socket node with
  # @option args [String] :host the hostname/ip which to listen on
  # @option args [Integer] :port the port which to listen on
  def initialize(args = {})
     super(args)
     @host      = args[:host]
     @port      = args[:port]

     @connections = []
     @connections_lock = Mutex.new

     @response_lock = Mutex.new
     @response_cv   = ConditionVariable.new
     @responses     = []

     @connection_event_handlers = {:closed => [], :error => []}
  end

  # Register connection event handler
  # @param [:error, :close] event the event to register the handler for
  # @param [Callable] handler block param to be added to array of handlers that are called when event occurs
  # @yield [WSNode] self is passed to each registered handler when event occurs
  def on(event, &handler)
    if @connection_event_handlers.keys.include?(event)
      @connection_event_handlers[event] << handler
    end
  end

  # Instruct Node to start listening for and dispatching rpc requests
  #
  # Implementation of {RJR::Node#listen}
  def listen
    em_run do
      EventMachine::WebSocket.start(:host => @host, :port => @port) do |ws|
        ws.onopen    { }
        ws.onclose   {       @connection_event_handlers[:closed].each { |h| h.call self } }
        ws.onerror   { |e|   @connection_event_handlers[:error].each  { |h| h.call self } }
        ws.onmessage { |msg| handle_msg(ws, msg) }
      end
    end
  end

  # Instructs node to send rpc request, and wait for / return response
  # @param [String] uri location of node to send request to, should be
  #   in format of ws://hostname:port
  # @param [String] rpc_method json-rpc method to invoke on destination
  # @param [Array] args array of arguments to convert to json and invoke remote method wtih
  def invoke_request(uri, rpc_method, *args)
    message = RequestMessage.new :method => rpc_method,
                                 :args   => args,
                                 :headers => @message_headers

    em_run{
      init_node(uri) do |c|
        c.stream { |msg| handle_msg(c, msg) }

        c.send_msg message.to_s
      end
    }

    # TODO optional timeout for response ?
    result = wait_for_result(message)

    if result.size > 2
      raise Exception, result[2]
    end
    return result[1]
  end

  # Instructs node to send rpc notification (immadiately returns / no response is generated)
  #
  # @param [String] uri location of node to send notification to, should be
  #   in format of ws://hostname:port
  # @param [String] rpc_method json-rpc method to invoke on destination
  # @param [Array] args array of arguments to convert to json and invoke remote method wtih
  def send_notification(uri, rpc_method, *args)
    # will block until message is published
    published_l = Mutex.new
    published_c = ConditionVariable.new

    message = NotificationMessage.new :method => rpc_method,
                                      :args   => args,
                                      :headers => @message_headers
    em_run{
      init_node(uri) do |c|
        c.send_msg message.to_s

        # XXX same bug w/ tcp node, due to nature of event machine
        # we aren't guaranteed that message is actually written to socket
        # here, process must be kept alive until data is sent or will be lost
        published_l.synchronize { published_c.signal }
      end
    }
    published_l.synchronize { published_c.wait published_l }
    nil
  end
end

end # module RJR
end
