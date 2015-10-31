# RJR Base Node Interface
#
# Copyright (C) 2012-2014 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'socket'
require 'rjr/messages'
require 'rjr/dispatcher'
require 'rjr/util/em_adapter'
require 'rjr/util/thread_pool'
require 'rjr/node_callback'

module RJR

# Base RJR Node interface. Nodes are the central transport mechanism of RJR,
# this class provides the core methods common among all transport types and
# mechanisms to start and run the subsystems which drives all requests.
#
# A subclass of RJR::Node should be defined for each transport that is supported.
# Each subclass should define 
#  * RJR_NODE_TYPE - unique id of the transport
#  * listen method - begin listening for new requests and return
#  * send_message(msg, connection) - send message using the specified connection
#    (transport dependent)
#  * invoke - establish connection, send message, and wait for / return result
#  * notify - establish connection, send message, and immediately return
#
# Not all methods necessarily have to be implemented depending on the context /
# use of the node, and the base node class provides many utility methods which
# to assist in message processing (see below).
#
# See nodes residing in lib/rjr/nodes/ for specific examples.
class Node

  ###################################################################

  # Unique string identifier of the node
  attr_reader :node_id

  # Attitional header fields to set on all
  # requests and responses received and sent by node
  attr_accessor :message_headers

  # Dispatcher to use to satisfy requests
  attr_accessor :dispatcher

  # Handlers for various connection events
  attr_reader :connection_event_handlers

  class <<self
    # Bool indiciting if this node is persistent
    def persistent?
      self.const_defined?(:PERSISTENT_NODE) &&
      self.const_get(:PERSISTENT_NODE)
    end

    # Bool indiciting if this node is indirect
    def indirect?
      self.const_defined?(:INDIRECT_NODE) &&
      self.const_get(:INDIRECT_NODE)
    end
  end

  # Bool indicating if this node class is persistent
  def persistent?
    self.class.persistent?
  end

  # Bool indicating if this node class is indirect
  def indirect?
    self.class.indirect?
  end

  # alias of RJR_NODE_TYPE
  def node_type
    self.class.const_defined?(:RJR_NODE_TYPE) ?
    self.class.const_get(:RJR_NODE_TYPE) : nil
  end

  def self.em
    defined?(@@em) ? @@em : nil
  end

  def em
    self.class.em
  end

  def self.tp
    defined?(@@tp) ? @@tp : nil
  end

  def tp
    self.class.tp
  end

  # RJR::Node initializer
  #
  # @param [Hash] args options to set on request
  # @option args [String] :node_id unique id of the node
  # @option args [Hash<String,String>] :headers optional headers to set
  #   on all json-rpc messages
  # @option args [Dispatcher] :dispatcher dispatcher to assign to the node
  def initialize(args = {})
     clear_event_handlers
     @response_lock = Mutex.new
     @response_cv   = ConditionVariable.new
     @pending       = {}
     @responses     = []

     @node_id         = args[:node_id]
     @timeout         = args[:timeout]
     @wait_interval   = args[:wait_interval] || 0.01
     @dispatcher      = args[:dispatcher] || RJR::Dispatcher.new
     @message_headers = args.has_key?(:headers) ? {}.merge(args[:headers]) : {}

     @@tp ||= ThreadPool.new
     @@em ||= EMAdapter.new

     # will do nothing if already started
     tp.start
     em.start
  end

  # Block until the eventmachine reactor and thread pool have both
  # completed running.
  #
  # @return self
  def join
    tp.join
    em.join
    self
  end

  # Immediately terminate the node
  #
  # *Warning* this does what it says it does. All running threads,
  # and reactor jobs are immediately killed
  #
  # @return self
  def halt
    em.stop_event_loop
    tp.stop
    self
  end

  ##################################################################
  # Reset connection event handlers
  def clear_event_handlers
    @connection_event_handlers = {
      :opened => [],
      :closed => [],
      :error  => []
    }
  end

  # Register connection event handler
  # @param event [:opened, :closed, :error] the event to register the handler
  #                                         for
  # @param handler [Callable] block param to be added to array of handlers
  #                           that are called when event occurs
  # @yield [Node, *args] self and event-specific *args are passed to each
  #                      registered handler when event occurs
  def on(event, &handler)
    return unless @connection_event_handlers.keys.include?(event)
    @connection_event_handlers[event] << handler
  end

  private

  # Internal helper, run connection event handlers for specified event, passing
  # self and args to handler
  def connection_event(event, *args)
    return unless @connection_event_handlers.keys.include?(event)
    @connection_event_handlers[event].each { |h| h.call(self, *args) }
  end

  ##################################################################

  # Internal helper, extract client info from connection
  def client_for(connection)
    # skip if an indirect node type or local
    return nil, nil if self.indirect? || self.node_type == :local

    begin
      return Socket.unpack_sockaddr_in(connection.get_peername)
    rescue Exception=>e
    end

    return nil, nil
  end

  # Internal helper, handle message received
  def handle_message(msg, connection = {})
    intermediate = Messages::Intermediate.parse(msg)

    if Messages::Request.is_request_message?(intermediate)
      tp << ThreadPoolJob.new(intermediate) { |i|
              handle_request(i, false, connection)
            }

    elsif Messages::Notification.is_notification_message?(intermediate)
      tp << ThreadPoolJob.new(intermediate) { |i|
              handle_request(i, true, connection)
            }

    elsif Messages::Response.is_response_message?(intermediate)
      handle_response(intermediate)

    end

    intermediate
  end

  # Internal helper, handle request message received
  def handle_request(message, notification=false, connection={})
    # get client for the specified connection
    # TODO should grap port/ip immediately on connection and use that
    client_port,client_ip = client_for(connection)

    msg = notification ?
      Messages::Notification.new(:message => message,
                                 :headers => @message_headers) :
           Messages::Request.new(:message => message,
                                 :headers => @message_headers)

    callback = NodeCallback.new(:node       => self,
                                :connection => connection)

    result = @dispatcher.dispatch(:rjr_method      => msg.jr_method,
                                  :rjr_method_args => msg.jr_args,
                                  :rjr_headers     => msg.headers,
                                  :rjr_client_ip   => client_ip,
                                  :rjr_client_port => client_port,
                                  :rjr_node        => self,
                                  :rjr_node_id     => node_id,
                                  :rjr_node_type   => self.node_type,
                                  :rjr_callback    => callback)

    unless notification
      response = Messages::Response.new(:id      => msg.msg_id,
                                        :result  => result,
                                        :headers => msg.headers,
                                        :request => msg)
      self.send_msg(response.to_s, connection)
      return response
    end

    nil
  end

  # Internal helper, handle response message received
  def handle_response(message)
    msg    = Messages::Response.new(:message => message,
                                    :headers => self.message_headers)
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

  # Internal helper, block until response matching message id is received
  def wait_for_result(message)
    res = nil
    message_id = message.msg_id
    @pending[message_id] = Time.now
    while res.nil?
      @response_lock.synchronize{
        # Prune messages that timed out
        if @timeout
          now = Time.now
          @pending.delete_if { |_, start_time| (now - start_time) > @timeout }
        end
        pending_ids = @pending.keys
        raise Exception, 'Timed out' unless pending_ids.include? message_id

        # Prune invalid responses
        @responses.keep_if { |response| @pending.has_key? response.first }
        res = @responses.find { |response| message.msg_id == response.first }
        if !res.nil?
          @responses.delete(res)
        else
          @response_cv.wait @response_lock, @wait_interval
        end
      }
    end
    return res
  end
end # class Node
end # module RJR
