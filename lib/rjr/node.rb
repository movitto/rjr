# RJR Node
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

# establish client connection w/ specified args and invoke block w/ 
# newly created client, returning it after block terminates

require 'eventmachine'
require 'rjr/thread_pool'

module RJR

# Defines a node which can be used to dispatch rpc requests and/or register
# handlers for incomping requests.
class Node
  # node always has a node id
  attr_reader :node_id

  # attitional parameters to set on messages
  attr_accessor :message_headers

  attr_reader :thread_pool

  def initialize(args = {})
     @node_id = args[:node_id]

     @message_headers = {}
     @message_headers.merge!(args[:headers]) if args.has_key?(:headers)

     ObjectSpace.define_finalizer(self, self.class.finalize(self))
  end

  def self.finalize(node)
    proc { node.halt ; node.join }
  end

  # run job in event machine
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

  def em_running?
    @@em_jobs > 0 && EventMachine.reactor_running?
  end

  def join
    @@em_thread.join if @@em_thread
    @@em_thread = nil
    @thread_pool.join if @thread_pool
    @thread_pool = nil
  end

  def stop
    @@em_jobs -= 1
    if @@em_jobs == 0
      EventMachine.stop_event_loop
      @thread_pool.stop
    end
  end

  def halt
    @@em_jobs = 0
    EventMachine.stop
    @thread_pool.stop unless @thread_pool.nil?
  end

end
end # module RJR
