# RJR TCP Endpoint
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'uri'
require 'eventmachine'

require 'rjr/node'
require 'rjr/message'

module RJR

# TCP client node callback interface,
# send data back to client via established tcp socket.
class TCPNodeCallback
  def initialize(args = {})
    @endpoint        = args[:endpoint]
    @message_headers = args[:headers]
  end

  def invoke(callback_method, *data)
    msg = RequestMessage.new :method => callback_method, :args => data, :headers => @message_headers
    # TODO surround w/ begin/rescue block incase of socket errors
    @endpoint.send_data msg.to_s
  end
end

# helper class intialized by event machine corresponding to
# a client or server socket connection
class TCPNodeEndpoint < EventMachine::Connection
  def initialize(args = {})
    @rjr_node        = args[:rjr_node]

    # these params should be set for clients
    @send_message    = args[:init_message]
  end

  def post_init
    unless @send_message.nil?
      send_data @send_message.to_s
      @send_message = nil
    end
  end

  def receive_data(data)
    if RequestMessage.is_request_message?(data)
      @rjr_node.thread_pool << ThreadPoolJob.new { handle_request(data) }

    elsif ResponseMessage.is_response_message?(data)
      handle_response(data)

    end
  end


  def handle_request(data)
    client_port, client_ip = Socket.unpack_sockaddr_in(get_peername)
    msg    = RequestMessage.new(:message => data, :headers => @rjr_node.message_headers)
    headers = @rjr_node.message_headers.merge(msg.headers)
    result = Dispatcher.dispatch_request(msg.jr_method,
                                         :method_args => msg.jr_args,
                                         :headers => headers,
                                         :client_ip     => client_ip,
                                         :client_port   => client_port,
                                         :rjr_node      => @rjr_node,
                                         :rjr_node_id   => @rjr_node.node_id,
                                         :rjr_node_type => TCPNode::RJR_NODE_TYPE,
                                         :rjr_callback =>
                                           TCPNodeCallback.new(:endpoint => self,
                                                               :headers => headers))
    response = ResponseMessage.new(:id => msg.msg_id, :result => result, :headers => headers)
    send_data(response.to_s)
  end

  def handle_response(data)
    msg    = ResponseMessage.new(:message => data, :headers => @rjr_node.message_headers)
    res = err = nil
    begin
      res = Dispatcher.handle_response(msg.result)
    rescue Exception => e
      err = e
    end

    @rjr_node.response_lock.synchronize {
      @rjr_node.responses << [msg.msg_id, res]
      @rjr_node.responses.last << err unless err.nil?
      @rjr_node.response_cv.signal
    }
  end
end

# TCP node definition, listen for and invoke json-rpc requests via tcp sockets
class TCPNode < RJR::Node
  RJR_NODE_TYPE = :tcp

  attr_accessor :response_lock
  attr_accessor :response_cv
  attr_accessor :responses

  public
  # initialize the node w/ the specified params
  def initialize(args = {})
     super(args)
     @host      = args[:host]
     @port      = args[:port]

     @response_lock = Mutex.new
     @response_cv   = ConditionVariable.new
     @response_cv   = ConditionVariable.new
     @response_check_cv   = ConditionVariable.new
     @responses     = []

     @connection_event_handlers = {:closed => [], :error => []}
  end

  # register connection event handler
  def on(event, &handler)
    if @connection_event_handlers.keys.include?(event)
      @connection_event_handlers[event] << handler
    end
  end

  # Initialize the tcp subsystem
  def init_node
  end

  # Instruct Node to start listening for and dispatching rpc requests
  def listen
    em_run {
      init_node
      EventMachine::start_server @host, @port, TCPNodeEndpoint, { :rjr_node => self }
    }
  end

  # Instructs node to send rpc request, and wait for / return response
  def invoke_request(uri, rpc_method, *args)
    uri = URI.parse(uri)
    host,port = uri.host, uri.port

    message = RequestMessage.new :method => rpc_method,
                                 :args   => args,
                                 :headers => @message_headers
    em_run{
      init_node
      EventMachine::connect host, port, TCPNodeEndpoint, { :rjr_node     => self,
                                                           :init_message => message }
    }

    # wait for matching response
    res = nil
    while res.nil?
      @response_lock.synchronize {
        @response_cv.wait response_lock
        res = @responses.select { |response| message.msg_id == response.first }.first
        unless res.nil?
          @responses.delete(res)
        else
          @response_cv.signal
          @response_check_cv.wait @response_lock
        end
        @response_check_cv.signal
      }
    end

    # raise error or return result
    if res.size > 2
      raise res[2]
    end
    return res[1]
  end
end

end # module RJR
