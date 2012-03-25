# RJR WebSockets Endpoint
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the AGPLv3+ http://www.gnu.org/licenses/agpl.txt

# establish client connection w/ specified args and invoke block w/ 
# newly created client, returning it after block terminates

require 'em-websocket'
require 'rjr/web_socket'

require 'rjr/node'
require 'rjr/message'

module RJR

# Web Socket client node callback interface,
# send data back to client via established web socket.
class WSNodeCallback
  def initialize(args = {})
    @socket    = args[:socket]
    @message_headers = args[:headers]

    # FIXME onclose, invalidate this callback / terminate outstanding handlers
    #@socket.onclose {}
    #@socket.onerror { |error|}
  end

  def invoke(callback_method, *data)
    #msg = CallbackMessage.new(:data => data)
    msg = RequestMessage.new :method => callback_method, :args => data, :headers => @message_headers
    raise RJR::Errors::ConnectionError.new("websocket closed") if @socket.state == :closed
    @socket.send(msg.to_s)
  end
end

# Web node definition, listen for and invoke json-rpc requests via web sockets
class WSNode < RJR::Node
  RJR_NODE_TYPE = :websockets

  private
  def handle_request(socket, message)
    msg    = RequestMessage.new(:message => message, :headers => @message_headers)
    headers = @message_headers.merge(msg.headers)
    result = Dispatcher.dispatch_request(msg.jr_method,
                                         :method_args => msg.jr_args,
                                         :headers => headers,
                                         :rjr_node_id   => @node_id,
                                         :rjr_node_type => RJR_NODE_TYPE,
                                         :rjr_callback =>
                                           WSNodeCallback.new(:socket => socket,
                                                              :headers => headers))
    response = ResponseMessage.new(:id => msg.msg_id, :result => result, :headers => headers)
    socket.send(response.to_s)
  end

  public
  # initialize the node w/ the specified params
  def initialize(args = {})
     super(args)
     @host      = args[:host]
     @port      = args[:port]
  end

  # Initialize the ws subsystem
  def init_node
  end

  # Instruct Node to start listening for and dispatching rpc requests
  def listen
    em_run do
      init_node
      EventMachine::WebSocket.start(:host => @host, :port => @port) do |ws|
        ws.onopen    {   }
        ws.onclose   {   }
        ws.onerror   {|e|}
        ws.onmessage { |msg|
          # TODO should delete handler threads as they complete & should handle timeout
          @thread_pool << ThreadPoolJob.new { handle_request(ws, msg) }
        }
      end
    end
  end

  # Instructs node to send rpc request, and wait for / return response
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
