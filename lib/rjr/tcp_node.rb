# RJR TCP Endpoint
#
# Implements the RJR::Node interface to satisty JSON-RPC requests over the TCP protocol
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'uri'
require 'socket'
require 'eventmachine'

require 'rjr/node'
require 'rjr/message'
require 'rjr/message'
require 'rjr/dispatcher'
require 'rjr/errors'
require 'rjr/thread_pool'

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
    msg = NotificationMessage.new :method => callback_method, :args => data, :headers => @message_headers
    # TODO surround w/ begin/rescue block incase of socket errors / raise RJR::ConnectionError
    @endpoint.safe_send msg.to_s
  end
end

# @private
# Helper class intialized by eventmachine encapsulating a socket connection
class TCPNodeEndpoint < EventMachine::Connection

  attr_reader :host
  attr_reader :port

  # TCPNodeEndpoint intializer
  #
  # specify the TCPNode establishing the connection
  def initialize(args = {})
    @rjr_node = args[:rjr_node]
    @host = args[:host]
    @port = args[:port]

    # used to serialize requests to send data via a connection
    @send_lock = Mutex.new
  end

  # {EventMachine::Connection#receive_data} callback, handle request / response messages
  def receive_data(data)
    # a large json-rpc message may be split over multiple packets (invocations of receive_data)
    # and multiple messages may be concatinated into one packet
    @data ||= ""
    @data += data
    while extracted = MessageUtil.retrieve_json(@data)
      msg, @data = *extracted
      if RequestMessage.is_request_message?(msg)
        ThreadPoolManager << ThreadPoolJob.new(msg) { |m| handle_request(m, false) }

      elsif NotificationMessage.is_notification_message?(msg)
        ThreadPoolManager << ThreadPoolJob.new(msg) { |m| handle_request(m, true) }

      elsif ResponseMessage.is_response_message?(msg)
        handle_response(msg)

      end
    end
  end

  # {EventMachine::Connection#unbind} callback, connection was closed
  def unbind
  end

  # Helper to send data safely, this should be invoked instead of send_data
  # in all cases
  def safe_send(data)
    @send_lock.synchronize{
      send_data(data)
    }
  end


  private

  # Internal helper, handle request message received
  def handle_request(data, notification=false)
    # XXX hack to handle client disconnection (should grap port/ip immediately on connection and use that)
    client_port,client_ip = nil,nil
    begin
      client_port, client_ip = Socket.unpack_sockaddr_in(get_peername)
    rescue Exception=>e
    end

    msg    = notification ? NotificationMessage.new(:message => data, :headers => @rjr_node.message_headers) :
                            RequestMessage.new(:message => data, :headers => @rjr_node.message_headers)
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
    unless notification
      response = ResponseMessage.new(:id => msg.msg_id, :result => result, :headers => headers)
      safe_send(response.to_s)
    end
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

  attr_accessor :connections

  attr_accessor :response_lock
  attr_accessor :response_cv
  attr_accessor :responses

  private
  # Internal helper, initialize new connection
  def init_node(args={}, &on_init)
    host,port = args[:host], args[:port]
    connection = nil
    @connections_lock.synchronize {
      connection = @connections.find { |c|
                     port == c.port && host == c.host
                   }
      if connection.nil?
        connection =
          EventMachine::connect host, port,
                      TCPNodeEndpoint, args
        @connections << connection
      end
    }
    on_init.call(connection)
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
  # TCPNode initializer
  # @param [Hash] args the options to create the tcp node with
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
    em_run{
      init_node(:host => host, :port => port,
                :rjr_node => self) { |c|
        c.safe_send message.to_s
      }
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
  #   in format of jsonrpc://hostname:port
  # @param [String] rpc_method json-rpc method to invoke on destination
  # @param [Array] args array of arguments to convert to json and invoke remote method wtih
  def send_notification(uri, rpc_method, *args)
    # will block until message is published
    published_l = Mutex.new
    published_c = ConditionVariable.new

    uri = URI.parse(uri)
    host,port = uri.host, uri.port

    invoked = false
    conn    = nil
    message = NotificationMessage.new :method => rpc_method,
                                      :args   => args,
                                      :headers => @message_headers
    em_run{
      init_node(:host => host, :port => port,
                :rjr_node => self) { |c|
        conn = c
        c.safe_send message.to_s
        # XXX big bug w/ tcp node, this should be invoked only when
        # we are sure event machine sent message
        published_l.synchronize { invoked = true ; published_c.signal }
      }
    }
    published_l.synchronize { published_c.wait published_l unless invoked }
    #sleep 0.01 until conn.get_outbound_data_size == 0
    nil
  end
end

end # module RJR
