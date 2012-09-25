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

  # RJR::Node initializer
  # @param [Hash] args options to set on request
  # @option args [String] :node_id unique id of the node *required*!!!
  # @option args [Hash<String,String>] :headers optional headers to set on all json-rpc messages
  # @option args [Integer] :threads number of handler to threads to instantiate in local worker pool
  # @option args [Integer] :timeout timeout after which worker thread being run is killed
  def initialize(args = {})
     RJR::Node.default_threads ||=  10
     RJR::Node.default_timeout ||=  5

     @node_id     = args[:node_id]
     @num_threads = args[:threads]  || RJR::Node.default_threads
     @timeout     = args[:timeout]  || RJR::Node.default_timeout
     @keep_alive  = args[:keep_alive] || false

     @message_headers = {}
     @message_headers.merge!(args[:headers]) if args.has_key?(:headers)
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
