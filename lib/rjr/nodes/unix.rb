# RJR Unix Socket Node
#
# Implements the RJR::Node interface to issue and satisty JSON-RPC requests
# via Unix Sockets
#
# Copyright (C) 2013 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

# TODO extract common bits between here &
# tcp node into common base socked module

require 'thread'
require 'eventmachine'

require 'rjr/node'
require 'rjr/messages'
require 'rjr/util/json_parser'

module RJR
module Nodes

# @private
# Helper class intialized by eventmachine encapsulating a unix socket connection
class UnixConnection < EventMachine::Connection
  attr_reader :socketname

  # UnixConnection intializer
  #
  # Specify the Unix Node establishing the connection and
  # optionaly socketname which this connection is connected to
  def initialize(args = {})
    @rjr_node   = args[:rjr_node]
    @socketname = args[:socketname]

    @send_lock = Mutex.new
    @data      = ""
  end

  # EventMachine::Connection#receive_data callback, handle request / response messages
  def receive_data(data)
    # a large json-rpc message may be split over multiple packets
    #   (invocations of receive_data)
    # and multiple messages may be concatinated into one packet
    @data += data
    while extracted = JSONParser.extract_json_from(@data)
      msg, @data = *extracted
      @rjr_node.send(:handle_message, msg, self) # XXX private method
    end
  end

  # Send data safely using local connection
  def send_msg(data)
    @send_lock.synchronize{
      Unix.em.schedule { send_data(data) }
    }
  end
end

# Unix node definition, listen for and invoke json-rpc requests via Unix Sockets
#
# Clients should specify the socketname when listening for requests and
# when invoking them.
#
# TODO client / server examples
#
class Unix < RJR::Node
  RJR_NODE_TYPE = :unix
  PERSISTENT_NODE = true
  INDIRECT_NODE = false

  attr_accessor :connections

  private
  # Internal helper, initialize new client
  def init_client(args={}, &on_init)
    socketname = args[:socketname]
    connection = nil
    @connections_lock.synchronize {
      connection = @connections.find { |c|
                     socketname == c.socketname
                   }
      if connection.nil?
        connection =
          EventMachine::connect_unix_domain socketname,
                      nil, UnixConnection, args
        @connections << connection
      end
    }
    on_init.call(connection) # TODO move to unixnode event ?
  end

  public

  # Unix initializer
  # @param [Hash] args the options to create the unix node with
  # @option args [String] :socketname the name of the socket which to listen on
  def initialize(args = {})
     super(args)
     @socketname = args[:socketname]

     @connections = []
     @connections_lock = Mutex.new
  end

  def to_s
    "RJR::Nodes::Unix<#{@node_id},#{@socketname}>"
  end

  # Send data using specified connection
  #
  # Implementation of RJR::Node#send_msg
  def send_msg(data, connection)
    connection.send_msg(data)
  end

  # Instruct Node to start listening for and dispatching rpc requests
  #
  # Implementation of RJR::Node#listen
  def listen
    @@em.schedule {
      @@em.start_unix_domain_server @socketname, nil, UnixConnection, { :rjr_node => self }
    }
    self
  end

  # Instructs node to send rpc request, and wait for / return response.
  #
  # Implementation of RJR::Node#invoke
  #
  # Do not invoke directly from em event loop or callback as will block the message
  # subscription used to receive responses
  #
  # @param [String] socketname name of socket which destination node is
  #   listening on
  # @param [String] rpc_method json-rpc method to invoke on destination
  # @param [Array] args array of arguments to convert to json and invoke remote method wtih
  def invoke(socketname, rpc_method, *args)
    message = Messages::Request.new :method => rpc_method,
                                    :args   => args,
                                    :headers => @message_headers
    connection = nil
    @@em.schedule {
      init_client(:socketname => socketname,
                  :rjr_node => self) { |c|
        connection = c
        c.send_msg message.to_s
      }
    }

    # TODO optional timeout for response ?
    result = wait_for_result(message)

    if result.size > 2
      fail result[2]
    end
    return result[1]
  end

  # Instructs node to send rpc notification (immadiately returns / no response is generated)
  #
  # Implementation of RJR::Node#notify
  #
  # @param [String] socketname name of socket which
  # destination node is listening on
  # @param [String] rpc_method json-rpc method to invoke on destination
  # @param [Array] args array of arguments to convert to json and invoke remote method wtih
  def notify(socketname, rpc_method, *args)
    # will block until message is published
    published_l = Mutex.new
    published_c = ConditionVariable.new

    invoked = false
    conn    = nil
    message = Messages::Notification.new :method => rpc_method,
                                         :args   => args,
                                         :headers => @message_headers
    @@em.schedule {
      init_client(:socketname => socketname,
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
end # class Unix

end # module Nodes
end # module RJR
