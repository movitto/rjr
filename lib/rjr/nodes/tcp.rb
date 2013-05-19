# RJR TCP Node
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
module Nodes

# @private
# Helper class intialized by eventmachine encapsulating a socket connection
class TCPConnection < EventMachine::Connection
  attr_reader :host
  attr_reader :port

  # TCPConnection intializer
  #
  # specify the TCP establishing the connection
  def initialize(args = {})
    @rjr_node  = args[:rjr_node]
    @host      = args[:host]
    @port      = args[:port]

    @send_lock = Mutex.new
    @data      = ""
  end

  # {EventMachine::Connection#receive_data} callback, handle request / response messages
  def receive_data(data)
    # a large json-rpc message may be split over multiple packets
    #   (invocations of receive_data)
    # and multiple messages may be concatinated into one packet
    @data += data
    while extracted = MessageUtil.retrieve_json(@data)
      msg, @data = *extracted
      @rjr_node.send(:handle_message, msg, self) # XXX private method
    end
  end

  # Send data safely
  def send_msg(data)
    @send_lock.synchronize{
      send_data(data)
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
#   server = RJR::Nodes::TCP.new :node_id => 'server', :host => 'localhost', :port => '7777'
#   server.listen
#   server.join
#
# @example Invoking json-rpc requests over tcp
#   client = RJR::Nodes::TCP.new :node_id => 'client', :host => 'localhost', :port => '8888'
#   puts client.invoke_request('jsonrpc://localhost:7777', 'hello', 'mo')
#
class TCP < RJR::Node
  RJR_NODE_TYPE = :tcp

  attr_accessor :connections

  private
  # Internal helper, initialize new client
  def init_client(args={}, &on_init)
    host,port = args[:host], args[:port]
    connection = nil
    @connections_lock.synchronize {
      connection = @connections.find { |c|
                     port == c.port && host == c.host
                   }
      if connection.nil?
        connection =
          EventMachine::connect host, port,
                      TCPConnection, args
        @connections << connection
      end
    }
    on_init.call(connection) # TODO move to tcpnode event ?
  end

  public

  # TCP initializer
  # @param [Hash] args the options to create the tcp node with
  # @option args [String] :host the hostname/ip which to listen on
  # @option args [Integer] :port the port which to listen on
  def initialize(args = {})
     super(args)
     @host      = args[:host]
     @port      = args[:port]

     @connections = []
     @connections_lock = Mutex.new

  end

  # Send data using specified connection
  def send_msg(data, connection)
    connection.send_msg(data)
  end

  # Instruct Node to start listening for and dispatching rpc requests
  #
  # Implementation of {RJR::Node#listen}
  def listen
    @em.schedule {
      @em.start_server @host, @port, TCPConnection, { :rjr_node => self }
    }
    self
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
  def invoke(uri, rpc_method, *args)
    uri = URI.parse(uri)
    host,port = uri.host, uri.port

    message = RequestMessage.new :method => rpc_method,
                                 :args   => args,
                                 :headers => @message_headers
    connection = nil
    @em.schedule {
      init_client(:host => host, :port => port,
                  :rjr_node => self) { |c|
        connection = c
        c.send_msg message.to_s
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
  def notify(uri, rpc_method, *args)
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
    @em.schedule {
      init_client(:host => host, :port => port,
                  :rjr_node => self) { |c|
        conn = c
        c.send_msg message.to_s
        # XXX, this should be invoked only when we are sure event
        # machine sent message. Shouldn't pose a problem unless event
        # machine is killed immediately after
        published_l.synchronize { invoked = true ; published_c.signal }
      }
    }
    published_l.synchronize { published_c.wait published_l unless invoked }
    #sleep 0.01 until conn.get_outbound_data_size == 0
    nil
  end
end

end # module Nodes
end # module RJR
