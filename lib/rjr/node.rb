# RJR Node
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

# establish client connection w/ specified args and invoke block w/ 
# newly created client, returning it after block terminates

require 'eventmachine'
require 'rjr/em_adapter'
require 'rjr/thread_pool2'

module RJR

# Base RJR Node interface. Nodes are the central transport mechanism of rjr,
# this class provides the core methods common among all transport types and
# mechanisms to start and run the eventmachine reactor which drives all requests.
#
# A subclass of RJR::Node should be defined for each transport that is supported,
# implementing the 'listen' operation to listen for new requests and 'invoke_request'
# to issue them.
class Node
  class << self
    # @!group Config options

    # Default number of threads to instantiate in local worker pool
    attr_accessor :default_threads

    # Default timeout after which worker threads are killed
    attr_accessor :default_timeout

    # @!endgroup
  end

  # Unique string identifier of the node
  attr_reader :node_id

  # Attitional header fields to set on all
  # requests and responses received and sent by node
  attr_accessor :message_headers

  # boolean indicating if connection / event machine should be
  # kept alive inbetween requests
  attr_accessor :keep_alive

  # RJR::Node initializer
  #
  # *Note* set keep_alive to true if you intended to use
  # the node from parallel threads (and manually halt
  # the node when appropriate in your application)
  #
  # @param [Hash] args options to set on request
  # @option args [String] :node_id unique id of the node *required*!!!
  # @option args [Hash<String,String>] :headers optional headers to set on all json-rpc messages
  # @option args [Integer] :threads number of handler to threads to instantiate in local worker pool
  # @option args [Integer] :timeout timeout after which worker thread being run is killed
  # @option args [boolean] :keep_alive boolean indicating if connections / event machine should be
  #                        kept alive inbetween requests
  def initialize(args = {})
     RJR::Node.default_threads ||=  20
     RJR::Node.default_timeout ||=  10

     @node_id     = args[:node_id]
     @num_threads = args[:threads]  || RJR::Node.default_threads
     @timeout     = args[:timeout]  || RJR::Node.default_timeout
     @keep_alive  = args[:keep_alive] || false

     @message_headers = {}
     @message_headers.merge!(args[:headers]) if args.has_key?(:headers)
  end

  # Initialize the node, should be called from the event loop
  # before any operation
  def init_node
    EM.error_handler { |e|
      puts "EventMachine raised critical error #{e} #{e.backtrace}"
      # TODO dispatch to registered event handlers (unify events system)
    }
  end

  # Run a job in event machine.
  # @param [Callable] bl callback to be invoked by eventmachine
  def em_run(&bl)
    # Nodes use shared thread pool to handle requests and free
    # up the eventmachine reactor to continue processing requests
    # @see ThreadPool2, ThreadPool2Manager
    ThreadPool2Manager.init @num_threads, :timeout => @timeout

    # Nodes make use of an EM helper interface to schedule operations
    EMAdapter.init :keep_alive => @keep_alive

    EMAdapter.schedule &bl
  end

  # Run a job async in event machine immediately
  def em_run_async(&bl)
    # same init as em_run
    ThreadPool2Manager.init @num_threads, :timeout => @timeout
    EMAdapter.init :keep_alive => @keep_alive
    EMAdapter.schedule {
      ThreadPool2Manager << ThreadPool2Job.new { bl.call }
    }
  end

  # TODO em_schedule

  # Run an job async in event machine.
  #
  # This schedules a thread to be run once after a specified
  # interval via eventmachine
  #
  # @param [Integer] seconds interval which to wait before invoking block
  # @param [Callable] bl callback to be periodically invoked by eventmachine
  def em_schedule_async(seconds, &bl)
    # same init as em_run
    ThreadPool2Manager.init @num_threads, :timeout => @timeout
    EMAdapter.init :keep_alive => @keep_alive
    EMAdapter.add_timer(seconds) {
      ThreadPool2Manager << ThreadPool2Job.new { bl.call }
    }
  end

  # Run a job periodically via an event machine timer
  #
  # @param [Integer] seconds interval which to invoke block
  # @param [Callable] bl callback to be periodically invoked by eventmachine
  def em_repeat(seconds, &bl)
    # same init as em_run
    ThreadPool2Manager.init @num_threads, :timeout => @timeout
    EMAdapter.init :keep_alive => @keep_alive
    EMAdapter.add_periodic_timer seconds, &bl
  end

  # Run an job async via an event machine timer.
  #
  # This schedules a thread to be run in the thread pool on
  # every invocation of a periodic event machine timer.
  #
  # @param [Integer] seconds interval which to invoke block
  # @param [Callable] bl callback to be periodically invoked by eventmachine
  def em_repeat_async(seconds, &bl)
    # same init as em_schedule
    ThreadPool2Manager.init @num_threads, :timeout => @timeout
    EMAdapter.init :keep_alive => @keep_alive
    EMAdapter.add_periodic_timer(seconds){
      ThreadPool2Manager << ThreadPool2Job.new { bl.call }
    }
  end

  # Block until the eventmachine reactor and thread pool have both completed running
  def join
    ThreadPool2Manager.join
    EMAdapter.join
  end

  # Terminate the node if no other jobs are running
  def stop
    if EMAdapter.stop
      ThreadPool2Manager.stop
    end
  end

  # Immediately terminate the node
  def halt
    EMAdapter.halt
    ThreadPool2Manager.stop
  end

end
end # module RJR
