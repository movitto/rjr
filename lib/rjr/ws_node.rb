# RJR WebSockets Endpoint
#
# Implements the RJR::Node interface to satisty JSON-RPC requests over the websockets protocol
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'em-websocket'
require 'rjr/web_socket'

require 'rjr/node'
require 'rjr/message'

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
    #msg = CallbackMessage.new(:data => data)
    msg = RequestMessage.new :method => callback_method, :args => data, :headers => @message_headers
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
  RJR_NODE_TYPE = :websockets

  private
  # Initialize the ws subsystem
  def init_node
  end

  # Internal helper, handle request message received
  def handle_request(socket, message)
    client_port, client_ip = Socket.unpack_sockaddr_in(socket.get_peername)
    msg    = RequestMessage.new(:message => message, :headers => @message_headers)
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
                                           WSNodeCallback.new(:socket => socket,
                                                              :headers => headers))
    response = ResponseMessage.new(:id => msg.msg_id, :result => result, :headers => headers)
    socket.send(response.to_s)
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
      init_node
      EventMachine::WebSocket.start(:host => @host, :port => @port) do |ws|
        ws.onopen    {}
        ws.onclose   {
          @connection_event_handlers[:closed].each { |h|
            h.call self
          }
        }
        ws.onerror   {|e|
          @connection_event_handlers[:error].each { |h|
            h.call self
          }
        }
        ws.onmessage { |msg|
          @thread_pool << ThreadPoolJob.new { handle_request(ws, msg) }
        }
      end
    end
  end

  # Instructs node to send rpc request, and wait for / return response
  # @param [String] uri location of node to send request to, should be
  #   in format of ws://hostname:port
  # @param [String] rpc_method json-rpc method to invoke on destination
  # @param [Array] args array of arguments to convert to json and invoke remote method wtih
  def invoke_request(uri, rpc_method, *args)
    init_node
    message = RequestMessage.new :method => rpc_method,
                                 :args   => args,
                                 :headers => @message_headers
    socket = WebSocket.new(uri)
    socket.send(message.to_s)
    res = socket.receive()
    msg    = ResponseMessage.new(:message => res, :headers => @message_headers)
    headers = @message_headers.merge(msg.headers)
    return Dispatcher.handle_response(msg.result)
  end
end

end # module RJR
