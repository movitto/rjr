# RJR AMQP Endpoint
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the AGPLv3+ http://www.gnu.org/licenses/agpl.txt

# establish client connection w/ specified args and invoke block w/ 
# newly created client, returning it after block terminates

require 'amqp'

module RJR

class AMQPNode < RJR::Node
  private
  def handle_request(reply_to, message)
    msg    = RequestMessage.new(:message => message)
    result = Dispatcher.dispatch_request(msg.jr_method, msg.jr_args)
    response = ResponseMessage.new(:id => msg.msg_id, :result => result)
    @exchange.publish(response.to_s, :routing_key => reply_to)
  end

  public

  # initialize the node w/ the specified params
  def initialize(args = {})
     super(args)
     @broker    = args[:broker]
     @response_queue = []
  end

  # Initialize the amqp subsystem
  def init_node
     @conn = AMQP.connect(:host => @broker)

     ### connect to qpid broker
     @channel = AMQP::Channel.new(@conn)

     # qpid constructs that will be created for node
     @queue_name  = "#{@node_id.to_s}-queue"
     @queue       = @channel.queue(@queue_name, :auto_delete => true)
     @exchange    = @channel.default_exchange
  end

  # Instruct Node to start listening for and dispatching rpc requests
  def listen
     EventMachine.run do
       init_node

       # start receiving messages
       @queue.subscribe do |metadata, msg|
          reply_to = metadata.reply_to

          # TODO should delete handler threads as they complete & should handle timeout
          @thread_pool << ThreadPoolJob.new { handle_request(reply_to, msg) }
       end 
     end
  end

  # Instructs node to send rpc request, and wait for / return response
  def invoke_request(routing_key, rpc_method, *args)
    EventMachine.run do
      init_node
      message = RequestMessage.new :method => rpc_method,
                                   :args   => args
      @exchange.publish(message.to_s, :routing_key => routing_key, :reply_to => @queue_name)

      # check responses already received for matching id
      @response_queue.each { |response|
        if response.id == message.id
          return Dispatcher.handle_response(response.result)
        end
      }

      ## wait for result
      @queue.subscribe do |metadata, msg|
        msg    = ResponseMessage.new(:message => msg)
        if msg.msg_id == message.msg_id
          return Dispatcher.handle_response(msg.result)
        else
          @response_queue << msg
        end
      end

      #return nil
    end
  end

end
end
