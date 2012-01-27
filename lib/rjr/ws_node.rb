# RJR WebSockets Endpoint
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the AGPLv3+ http://www.gnu.org/licenses/agpl.txt

# establish client connection w/ specified args and invoke block w/ 
# newly created client, returning it after block terminates

require 'em-websocket'

module RJR

class WSNode < RJR::Node
  private
  def handle_request(socket, message)
    msg    = RequestMessage.new(:message => message)
    result = Dispatcher.dispatch_request(msg.jr_method, msg.jr_args)
    response = ResponseMessage.new(:id => msg.msg_id, :result => result)
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

end # module RJR
