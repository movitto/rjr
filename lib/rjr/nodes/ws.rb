# RJR WebSockets Endpoint
#
# Implements the RJR::Node interface to satisty JSON-RPC requests
# over the websockets protocol
#
# Copyright (C) 2012-2013 Mohammed Morsi <mo@morsi.org>
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
require 'rjr/nodes/missing'
RJR::Nodes::WS = RJR::Nodes::Missing

else
require 'thread'

require 'rjr/node'
require 'rjr/message'

module RJR
module Nodes

# Web socket node definition, listen for and invoke json-rpc requests via web sockets
#
# Clients should specify the hostname / port when listening for and invoking requests.
#
# *note* the RJR javascript client also supports sending / receiving json-rpc
# messages over web sockets
#
# @example Listening for json-rpc requests over tcp
#   # initialize node
#   server = RJR::Nodes::WS.new :node_id => 'server', :host => 'localhost', :port => '7777'
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
# @example Invoking json-rpc requests over web sockets using rjr
#   client = RJR::Nodes::WS.new :node_id => 'client'
#   puts client.invoke_request('ws://localhost:7777', 'hello', 'mo')
#
class WS < RJR::Node
  RJR_NODE_TYPE = :ws
  PERSISTENT_NODE = true

  private

  # Internal helper initialize new client
  def init_client(uri, &on_init)
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

  public

  # WS initializer
  # @param [Hash] args the options to create the web socket node with
  # @option args [String] :host the hostname/ip which to listen on
  # @option args [Integer] :port the port which to listen on
  def initialize(args = {})
     super(args)
     @host      = args[:host]
     @port      = args[:port]

     @connections = []
     @connections_lock = Mutex.new
  end

  def to_s
    "RJR::Nodes::WS<#{@node_id},#{@host},#{@port}>"
  end

  # Send data using specified websocket safely
  #
  # Implementation of {RJR::Node#send_msg}
  def send_msg(data, ws)
    @@em.schedule { ws.send(data) }
  end

  # Instruct Node to start listening for and dispatching rpc requests
  #
  # Implementation of {RJR::Node#listen}
  def listen
    @@em.schedule do
      EventMachine::WebSocket.run(:host => @host, :port => @port) do |ws|
        ws.onopen    { }
        ws.onclose   {       @connection_event_handlers[:closed].each { |h| h.call self } }
        ws.onerror   { |e|   @connection_event_handlers[:error].each  { |h| h.call self } }
        ws.onmessage { |msg| handle_message(msg, ws) }
      end
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
  #   in format of ws://hostname:port
  # @param [String] rpc_method json-rpc method to invoke on destination
  # @param [Array] args array of arguments to convert to json and invoke remote method wtih
  def invoke(uri, rpc_method, *args)
    message = RequestMessage.new :method => rpc_method,
                                 :args   => args,
                                 :headers => @message_headers

    @@em.schedule {
      init_client(uri) do |c|
        c.stream { |msg| handle_message(msg.data, c) }

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
  # Implementation of {RJR::Node#notify}
  #
  # @param [String] uri location of node to send notification to, should be
  #   in format of ws://hostname:port
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
    @@em.schedule {
      init_client(uri) do |c|
        c.stream { |msg| handle_message(msg.data, c) }

        c.send_msg message.to_s

        # XXX same issue w/ tcp node, due to nature of event machine
        # we aren't guaranteed that message is actually written to socket
        # here, process must be kept alive until data is sent or will be lost
        published_l.synchronize { invoked = true ; published_c.signal }
      end
    }
    published_l.synchronize { published_c.wait published_l unless invoked }
    nil
  end
end

end # module Nodes
end # module RJR
end # (!skip_module)
