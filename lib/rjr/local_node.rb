# RJR Local Endpoint
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the AGPLv3+ http://www.gnu.org/licenses/agpl.txt

# establish client connection w/ specified args and invoke block w/ 
# newly created client, returning it after block terminates

module RJR

# Local client node callback interface,
# send data back to client via local handlers
class LocalNodeCallback
  def initialize(args = {})
    @node        = args[:node]
  end

  def invoke(callback_method, *data)
    @node.invoke_request(callback_method, *data)
  end
end

# Local node definition, listen for and invoke json-rpc
# requests via local handlers
class LocalNode < RJR::Node
  RJR_NODE_TYPE = :local

  # initialize the node w/ the specified params
  def initialize(args = {})
     super(args)
  end

  # Instruct Node to start listening for and dispatching rpc requests
  def listen
    em_run do
    end
  end

  # Instructs node to send rpc request, and wait for / return response
  def invoke_request(rpc_method, *args)
    0.upto(args.size).each { |i| args[i] = args[i].to_s if args[i].is_a?(Symbol) }
    message = RequestMessage.new :method => rpc_method,
                                 :args   => args,
                                 :headers => @message_headers
    result = Dispatcher.dispatch_request(rpc_method,
                                         :method_args => args,
                                         :headers => @message_headers,
                                         :rjr_node_type => RJR_NODE_TYPE,
                                         :rjr_callback =>
                                           LocalNodeCallback.new(:node => self,
                                                                 :headers => @message_headers))
    return Dispatcher.handle_response(result)
  end

end
end
