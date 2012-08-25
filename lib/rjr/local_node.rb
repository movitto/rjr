# RJR Local Endpoint
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the AGPLv3+ http://www.gnu.org/licenses/agpl.txt

# establish client connection w/ specified args and invoke block w/ 
# newly created client, returning it after block terminates

require 'rjr/node'
require 'rjr/message'

module RJR

# Local client node callback interface,
# send data back to client via local handlers
class LocalNodeCallback
  def initialize(args = {})
    @node        = args[:node]
  end

  def invoke(callback_method, *data)
    # TODO any exceptions from handler will propagate here, surround w/ begin/rescue block
    @node.invoke_request(callback_method, *data)
    # TODO support local_node 'disconnections'
  end
end

# Local node definition, listen for and invoke json-rpc
# requests via local handlers
class LocalNode < RJR::Node
  RJR_NODE_TYPE = :local

  # allow clients to override the node type for the local node
  attr_accessor :node_type

  # initialize the node w/ the specified params
  def initialize(args = {})
     super(args)
     @node_type = RJR_NODE_TYPE
  end

  # register connection event handler,
  # until we support manual disconnections of the local node, we don't
  # have to do anything here
  def on(event, &handler)
    # TODO raise error (for the time being)?
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

    # we serialize / unserialze messages to ensure local node complies
    # to same json-rpc restrictions as other nodes
    message = RequestMessage.new :message => message.to_s,
                                 :headers => @message_headers

    result = Dispatcher.dispatch_request(message.jr_method,
                                         :method_args => message.jr_args,
                                         :headers => @message_headers,
                                         :rjr_node      => self,
                                         :rjr_node_id   => @node_id,
                                         :rjr_node_type => @node_type,
                                         :rjr_callback =>
                                           LocalNodeCallback.new(:node => self,
                                                                 :headers => @message_headers))
    response = ResponseMessage.new(:id => message.msg_id,
                                   :result => result,
                                   :headers => @message_headers)

    # same comment on serialization/unserialization as above
    response = ResponseMessage.new(:message => response.to_s,
                                   :headers => @message_headers)
    return Dispatcher.handle_response(response.result)
  end

end
end
