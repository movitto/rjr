# RJR Node
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

# establish client connection w/ specified args and invoke block w/ 
# newly created client, returning it after block terminates

require 'eventmachine'
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
  # Unique string identifier of the node
  attr_reader :node_id

  # Attitional header fields to set on all
  # requests and responses received and sent by node
  attr_accessor :message_headers

  # Nodes use internal thread pools to handle requests and free
  # up the eventmachine reactor to continue processing requests
  # @see ThreadPool
  attr_reader :thread_pool

  # RJR::Node initializer
  # @param [Hash] args options to set on request
  # @option args [String] :node_id unique id of the node *required*!!!
  # @option args [Hash<String,String>] :headers optional headers to set on all json-rpc messages
  def initialize(args = {})
     @node_id = args[:node_id]

     @message_headers = {}
     @message_headers.merge!(args[:headers]) if args.has_key?(:headers)

     ObjectSpace.define_finalizer(self, self.class.finalize(self))
  end

  # Ruby ObjectSpace finalizer to ensure that node terminates all
  # operations when object is destroyed
  def self.finalize(node)
    proc { node.halt ; node.join }
  end

  # Run a job in event machine.
  #
  # This will start the eventmachine reactor and thread pool if not already
  # running, schedule the specified block to be run and immediately return.
  #
  # For use by subclasses to start listening and sending operations within
  # the context of event machine.
  #
  # Keeps track of an internal counter of how many times this was invoked so
  # a specific node can be shutdown / started up without affecting the
  # eventmachine reactor (@see #stop)
  def em_run(&bl)
    @@em_jobs ||= 0
    @@em_jobs += 1

    @@em_thread  ||= nil

    unless !@thread_pool.nil? && @thread_pool.running?
      # threads pool to handle incoming requests
      # FIXME make the # of threads and timeout configurable)
      @thread_pool = ThreadPool.new(10, :timeout => 5)
    end

    if @@em_thread.nil?
      @@em_thread  =
        Thread.new{
          begin
            EventMachine.run
          rescue Exception => e
            puts "Critical exception #{e}\n#{e.backtrace.join("\n")}"
          ensure
          end
        }
#sleep 0.5 until EventMachine.reactor_running? # XXX hacky way to do this
    end
    EventMachine.schedule bl
  end

  # Returns boolean indicating if this node is still running or not
  def em_running?
    @@em_jobs > 0 && EventMachine.reactor_running?
  end

  # Block until the eventmachine reactor and thread pool have both completed running
  def join
    @@em_thread.join if @@em_thread
    @@em_thread = nil
    @thread_pool.join if @thread_pool
    @thread_pool = nil
  end

  # Decrement the event machine job counter and if equal to zero,
  # immediately terminate the node
  def stop
    @@em_jobs -= 1
    if @@em_jobs == 0
      EventMachine.stop_event_loop
      @thread_pool.stop
    end
  end

  # Immediately terminate the node, halting the eventmachine reactor and
  # terminating the thread pool
  def halt
    @@em_jobs = 0
    EventMachine.stop
    @thread_pool.stop unless @thread_pool.nil?
  end

end
end # module RJR
