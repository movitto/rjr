# RJR TCP Endpoint
#
# Implements the RJR::Node interface to satisty JSON-RPC requests over the TCP protocol
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'uri'
require 'eventmachine'

require 'rjr/node'
require 'rjr/message'

module RJR

# TCP node callback interface, used to invoke json-rpc methods
# against a remote node via a tcp socket connection previously opened
#
# After a node sends a json-rpc request to another, the either node may send
# additional requests to each other via the socket already established until
# it is closed on either end
class TCPNodeCallback

  # TCPNodeCallback initializer
  # @param [Hash] args the options to create the tcp node callback with
  # @option args [TCPNodeEndpoint] :endpoint tcp node endpoint used to send/receive messages
  # @option args [Hash] :headers hash of rjr message headers present in client request when callback is established
  def initialize(args = {})
    @endpoint        = args[:endpoint]
    @message_headers = args[:headers]
  end

  # Implementation of {RJR::NodeCallback#invoke}
  def invoke(callback_method, *data)
    msg = RequestMessage.new :method => callback_method, :args => data, :headers => @message_headers
    # TODO surround w/ begin/rescue block incase of socket errors
    @endpoint.send_data msg.to_s
  end
end

# @private
# Helper class intialized by eventmachine encapsulating a socket connection
class TCPNodeEndpoint < EventMachine::Connection

  # TCPNodeEndpoint intializer
  #
  # specify the TCPNode establishing the connection and an optional first message to send
  def initialize(args = {})
    @rjr_node        = args[:rjr_node]

    # these params should be set for clients
    @send_message    = args[:init_message]
  end

  # {EventMachine::Connection#post_init} callback, sends first message if specified
  def post_init
    unless @send_message.nil?
      send_data @send_message.to_s
      @send_message = nil
    end
  end

  # {EventMachine::Connection#receive_data} callback, handle request / response messages
  def receive_data(data)
    if RequestMessage.is_request_message?(data)
      ThreadPool2Manager << ThreadPool2Job.new { handle_request(data) }

    elsif ResponseMessage.is_response_message?(data)
      handle_response(data)

    end
  end


  private

  # Internal helper, handle request message received
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

  # Internal helper, handle response message received
  def handle_response(data)
    msg    = ResponseMessage.new(:message => data, :headers => @rjr_node.message_headers)
    res = err = nil
    begin
      res = Dispatcher.handle_response(msg.result)
    rescue Exception => e
      err = e
    end

    @rjr_node.response_lock.synchronize {
      result = [msg.msg_id, res]
      result << err if !err.nil?
      @rjr_node.responses << result
      @rjr_node.response_cv.signal
    }
  end
end

# TCP node definition, listen for and invoke json-rpc requests via TCP sockets
#
# Clients should specify the hostname / port when listening for requests and
# when invoking them.
#
# @example Listening for json-rpc requests over tcp
#   # register rjr dispatchers (see RJR::Dispatcher)
#   RJR::Dispatcher.add_handler('hello') { |name|
#     "Hello #{name}!"
#   }
#
#   # initialize node, listen, and block
#   server = RJR::TCPNode.new :node_id => 'server', :host => 'localhost', :port => '7777'
#   server.listen
#   server.join
#
# @example Invoking json-rpc requests over tcp
#   client = RJR::TCPNode.new :node_id => 'client', :host => 'localhost', :port => '8888'
#   puts client.invoke_request('jsonrpc://localhost:7777', 'hello', 'mo')
#
class TCPNode < RJR::Node
  RJR_NODE_TYPE = :tcp

  attr_accessor :response_lock
  attr_accessor :response_cv
  attr_accessor :responses

  private
  # Initialize the tcp subsystem
  def init_node
  end

  # Internal helper, block until response matching message id is received
  def wait_for_result(message)
    res = nil
    while res.nil?
      @response_lock.synchronize{
        @response_cv.wait @response_lock
        # FIXME throw err if more than 1 match found
        res = @responses.select { |response| message.msg_id == response.first }.first
        unless res.nil?
          @responses.delete(res)
        else
          # we can't just go back to waiting for message here, need to give
          # other nodes a chance to check it first
          @response_cv.signal
          @response_check_cv.wait @response_lock
        end
        @response_check_cv.signal
      }
    end
    return res
  end

  public
  # TCPNode initializer
  # @param [Hash] args the options to create the tcp node with
  # @option args [String] :host the hostname/ip which to listen on
  # @option args [Integer] :port the port which to listen on
  def initialize(args = {})
     super(args)
     @host      = args[:host]
     @port      = args[:port]

     @response_lock = Mutex.new
     @response_cv   = ConditionVariable.new
     @response_check_cv   = ConditionVariable.new
     @responses     = []

     @connection_event_handlers = {:closed => [], :error => []}
  end

  # Register connection event handler
  # @param [:error, :close] event the event to register the handler for
  # @param [Callable] handler block param to be added to array of handlers that are called when event occurs
  # @yield [TCPNode] self is passed to each registered handler when event occurs
  def on(event, &handler)
    if @connection_event_handlers.keys.include?(event)
      @connection_event_handlers[event] << handler
    end
  end

  # Instruct Node to start listening for and dispatching rpc requests
  #
  # Implementation of {RJR::Node#listen}
  def listen
    em_run {
      init_node
      EventMachine::start_server @host, @port, TCPNodeEndpoint, { :rjr_node => self }
    }
  end

  # Instructs node to send rpc request, and wait for / return response.
  #
  # Do not invoke directly from em event loop or callback as will block the message
  # subscription used to receive responses
  #
  # @param [String] uri location of node to send request to, should be
  #   in format of jsonrpc://hostname:port
  # @param [String] rpc_method json-rpc method to invoke on destination
  # @param [Array] args array of arguments to convert to json and invoke remote method wtih
  def invoke_request(uri, rpc_method, *args)
    uri = URI.parse(uri)
    host,port = uri.host, uri.port

    message = RequestMessage.new :method => rpc_method,
                                 :args   => args,
                                 :headers => @message_headers
    # honor keep_alive here, do not continuously reconnect
    em_run{
      init_node
      EventMachine::connect host, port, TCPNodeEndpoint, { :rjr_node     => self,
                                                           :init_message => message }
    }

    # TODO optional timeout for response ?
    result = wait_for_result(message)
    self.stop

    if result.size > 2
      raise Exception, result[2]
    end
    return result[1]
  end
end

end # module RJR
