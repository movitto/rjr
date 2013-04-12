# EventMachine Adapter
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'singleton'
require 'eventmachine'

# EventMachine wrapper / helper interface, ties reactor
# lifecycle to an instance of this class.
#
# TODO move to the RJR namespace
class EMManager

  # Run reactor in its own interally managed thread
  attr_accessor :reactor_thread

  # EMManager initializer
  def initialize
    @em_lock = Mutex.new
  end

  # Start the eventmachine reactor thread if not running
  def start
    @em_lock.synchronize{
      # TODO on event of the process ending this thread will be
      # shutdown before a local finalizer can be run,
      # would be good to gracefully shut this down / wait for completion
      @reactor_thread  = Thread.new {
        begin
          EventMachine.run
        rescue Exception => e
          # TODO option to autorestart the reactor on errors ?
          puts "Critical exception #{e}\n#{e.backtrace.join("\n")}"
        ensure
          @reactor_thread = nil
        end
       } unless @reactor_thread
     }
     sleep 0.01 until EventMachine.reactor_running? # XXX hack but needed
   end

  # Schedule a new job to be run in event machine
  # @param [Callable] bl callback to be invoked by eventmachine
  def schedule(&bl)
    EventMachine.schedule &bl
  end

  # Schedule a job to be run once after a specified interval in event machine
  # @param [Integer] seconds int interval which to wait before invoking specified block
  # @param [Callable] bl callback to be invoked by eventmachine
  def add_timer(seconds, &bl)
    EventMachine.add_timer(seconds, &bl)
  end

  # Schedule a block to be run periodically in event machine
  # @param [Integer] seconds int interval which to invoke specified block
  # @param [Callable] bl callback to be invoked by eventmachine
  def add_periodic_timer(seconds, &bl)
    EventMachine.add_periodic_timer(seconds, &bl)
  end

  # Return boolean indicating if event machine reactor is running
  def running?
    @em_lock.synchronize{
      EventMachine.reactor_running?
    }
  end

  # Block until reactor thread is terminated
  def join
    th = nil
    @em_lock.synchronize{
      th = @reactor_thread
    }
    th.join unless th.nil?
  end

  # Terminate the event machine reactor under all conditions
  def halt
    @em_lock.synchronize{
      EventMachine.stop_event_loop
    }
  end
end


# Provides an interface which to access a shared EMManager
#
# EMManager operations may be invoked on this class after
# the 'init' method is called
#
#     EMAdapter.init
#     EMAdapter.start
class EMAdapter
  # Initialize EM subsystem
  def self.init
    if @em_manager.nil?
      @em_manager = EMManager.new
    end

    @em_manager.start
  end

  # Delegates all methods invoked on calls to EMManager
  def self.method_missing(method_id, *args, &bl)
    @em_manager.send method_id, *args, &bl
  end

end
