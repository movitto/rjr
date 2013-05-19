# RJR Node
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'thread'
require 'socket'
require 'rjr/common'
require 'rjr/message'
require 'rjr/dispatcher'
require 'rjr/em_adapter'
require 'rjr/thread_pool'

module RJR

# Base RJR Node interface. Nodes are the central transport mechanism of rjr,
# this class provides the core methods common among all transport types and
# mechanisms to start and run the eventmachine reactor which drives all requests.
#
# A subclass of RJR::Node should be defined for each transport that is supported,
# implementing the 'listen' operation to listen for new requests and 'invoke_request'
# to issue them.
class Node

  # Subclasses should define RJR_NODE_TYPE and send_message

  ###################################################################

  # Unique string identifier of the node
  attr_reader :node_id

  # Attitional header fields to set on all
  # requests and responses received and sent by node
  attr_accessor :message_headers

  # Dispatcher to use to satisfy requests
  attr_accessor :dispatcher

  # RJR::Node initializer
  #
  # @param [Hash] args options to set on request
  # @option args [String] :node_id unique id of the node
  # @option args [Hash<String,String>] :headers optional headers to set on all json-rpc messages
  # @option args [Dispatcher] :dispatcher dispatcher to assign to the node
  def initialize(args = {})
     @connection_event_handlers = {:closed => [], :error => []}
     @response_lock = Mutex.new
     @response_cv   = ConditionVariable.new
     @responses     = []

     @node_id         = args[:node_id]
     @dispatcher      = args[:dispatcher] || RJR::Dispatcher.new
     @message_headers = args.has_key?(:headers) ? {}.merge(args[:headers]) : {}

     @tp = ThreadPool.instance.start
     @em = EMAdapter.instance.start
  end

  # Block until the eventmachine reactor and thread pool have both completed running
  def join
    @tp.join
    @em.join
    self
  end

  # Immediately terminate the node
  #
  # *Warning* this does what it says it does. All running threads, and reactor
  # jobs are immediately killed
  def halt
    @em.stop_event_loop
    @tp.stop
  end

  ##################################################################

  # Register connection event handler
  # @param [:error, :close] event the event to register the handler for
  # @param [Callable] handler block param to be added to array of handlers that are called when event occurs
  # @yield [TCPNode] self is passed to each registered handler when event occurs
  def on(event, &handler)
    if @connection_event_handlers.keys.include?(event)
      @connection_event_handlers[event] << handler
    end
  end

  private

  # Internal helper, run connection event handlers for specified event
  def connection_event(event)
    if @connection_event_handlers.keys.include?(event)
      @connection_event_handlers[event].each { |h|
        h.call self
      }
    end
  end

  ##################################################################

  # Handle message received
  def handle_message(msg, connection = {})
    if RequestMessage.is_request_message?(msg)
      @tp << ThreadPoolJob.new(msg) { |m| handle_request(m, false, connection) }

    elsif NotificationMessage.is_notification_message?(msg)
      @tp << ThreadPoolJob.new(msg) { |m| handle_request(m, true, connection) }

    elsif ResponseMessage.is_response_message?(msg)
      handle_response(msg)

    end
  end

  # Handle request message received
  def handle_request(data, notification=false, connection={})
    # get client for the specified connection
    # TODO should grap port/ip immediately on connection and use that
    client_port,client_ip = nil,nil
    begin
      # XXX skip if an 'indirect' node type or local
      unless [:amqp, :local].include?(self.class.RJR_NODE_TYPE)
        client_port, client_ip =
          Socket.unpack_sockaddr_in(connection.get_peername)
      end
    rescue Exception=>e
    end

    msg = notification ?
      NotificationMessage.new(:message => data,
                              :headers => @message_headers) :
            RequestMessage.new(:message => data,
                              :headers => @message_headers)

    result =
      @dispatcher.dispatch(:rjr_method      => msg.jr_method,
                           :rjr_method_args => msg.jr_args,
                           :headers         => msg.headers,
                           :client_ip       => client_port,
                           :client_port     => client_ip,
                           :rjr_node        => self,
                           :rjr_node_id     => @node_id,
                           :rjr_node_type   => self.class::RJR_NODE_TYPE,
                           :rjr_callback    =>
                             NodeCallback.new(:node       => self,
                                              :connection => connection))

    unless notification
      response = ResponseMessage.new(:id => msg.msg_id,
                                     :result => result,
                                     :headers => msg.headers)
      self.send_msg(response.to_s, connection)
      return response
    end
  end

  # Handle response message received
  def handle_response(data)
    msg    = ResponseMessage.new(:message => data, :headers => self.message_headers)
    res = err = nil
    begin
      res = @dispatcher.handle_response(msg.result)
    rescue Exception => e
      err = e
    end

    @response_lock.synchronize {
      result = [msg.msg_id, res]
      result << err if !err.nil?
      @responses << result
      @response_cv.broadcast
    }
  end

  # Block until response matching message id is received
  def wait_for_result(message)
    res = nil
    while res.nil?
      @response_lock.synchronize{
        # FIXME throw err if more than 1 match found
        res = @responses.find { |response| message.msg_id == response.first }
        if !res.nil?
          @responses.delete(res)

        else
          # FIXME if halt is invoked while this is sleeping, all other threads
          # may be deleted resulting in this sleeping indefinetly and a deadlock
          @response_cv.wait @response_lock

        end
      }
    end
    return res
  end

end # class Node

# Node callback interface, used to invoke json-rpc methods
# against a remote node via node connection previously established
#
# After a node sends a json-rpc request to another, the either node may send
# additional requests to each other via the connection already established until
# it is closed on either end
class NodeCallback

  # NodeCallback initializer
  # @param [Hash] args the options to create the tcp node callback with
  # @option args [node] :node node used to send messages
  # @option args [connection] :connection connection to be used in channel selection
  def initialize(args = {})
    @node        = args[:node]
    @connection  = args[:connection]
  end

  def notify(callback_method, *data)
    # XXX return if node type does not support
    # pesistent conntections (throw err instead?)
    return if @node.class::RJR_NODE_TYPE == :web

    msg = NotificationMessage.new :method => callback_method,
                                  :args => data, :headers => @node.message_headers

    # TODO surround w/ begin/rescue block incase of socket errors / raise RJR::ConnectionError
    @node.send_msg msg.to_s, @connection
  end
end

end # module RJR
