# EventMachine Adapter
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'singleton'

# EventMachine wrapper / helper interface, ties reactor
# lifecycle to an instance of this class
class EMManager

  # Run reactor in its own interally managed thread
  attr_accessor :reactor_thread

  # Number of jobs being run in the reactor
  attr_accessor :em_jobs

  # EMManager initializer
  def initialize
    @em_lock = Mutex.new
    @em_jobs = 0

    @keep_alive = false

     ObjectSpace.define_finalizer(self, self.class.finalize(self))
  end

  # Ruby ObjectSpace finalizer to ensure that EM is terminated
  def self.finalize(em_manager)
    proc { em_manager.halt ; em_manager.join }
  end

  # Update local em settings
  # @param [Hash] args options to set on em manager
  # @option args [Boolean] :keep_alive set to true to indicate event machine
  #   should be kept alive until 'halt' is called, set to false to indicate
  #   event machine should be terminated when there are no more pending operations
  def update(args = {})
    if args[:keep_alive]
      @keep_alive = true

    elsif args[:keep_alive] == false
      @keep_alive = false

    end
  end

  # Start the eventmachine reactor thread if not running
  def start
    @em_lock.synchronize{
      @reactor_thread  = Thread.new {
        begin
          EventMachine.run
        rescue Exception => e
          puts "Critical exception #{e}\n#{e.backtrace.join("\n")}"
        ensure
          @reactor_thread = nil
        end
       } unless @reactor_thread
     }
     sleep 0.1 until EventMachine.reactor_running? # XXX hack but needed
   end


  # Schedule a new job to be run in event machine
  # @param [Callable] bl callback to be invoked by eventmachine
  def schedule(&bl)
    @em_lock.synchronize{
      @em_jobs += 1
    }
    # TODO move into block? causes deadlock
    EventMachine.schedule bl
  end

  # Schedule a block to be run periodically in event machine
  # @param [Integer] seconds int interval which to invoke specified block
  # @param [Callable] bl callback to be invoked by eventmachine
  def add_periodic_timer(seconds, &bl)
    @em_lock.synchronize{
      @em_jobs += 1
    }
    # TODO move into block ?
    EventMachine.add_periodic_timer(seconds, &bl)
  end

  # Return boolean indicating if event machine reactor is running
  def running?
    @em_lock.synchronize{
      EventMachine.reactor_running?
    }
  end

  # Return boolean indicating if event machine has jobs to run
  def has_jobs?
    @em_lock.synchronize{
      @em_jobs > 0
    }
  end

  # Block until reactor thread is terminated
  def join
    @em_lock.synchronize{
      @reactor_thread.join unless @reactor_thread.nil?
    }
  end

  # Gracefully stop event machine if no jobs are running.
  # Set @keep_alive to true to ignore calls to stop
  def stop
    @em_lock.synchronize{
      old_em_jobs = @em_jobs
      @em_jobs -= 1
      if !@keep_alive && @em_jobs == 0
        EventMachine.stop_event_loop
        @reactor_thread.join
      end
      old_em_jobs != 0 && @em_jobs == 0 # only return true if this operation stopped the reactor
    }
  end

  # Terminate the event machine reactor under all conditions
  def halt
    @em_lock.synchronize{
      EventMachine.stop_event_loop
      #@reactor_thread.join
    }
  end
end


# Provides a singleton helper interface which to access
# a shared EMManager
#
# EMManager operations may be invoked on this class after
# the 'init' method is called
#
#     EMAdapter.init
#     EMAdapter.start
class EMAdapter
  include Singleton

  # Initialize EM subsystem
  def self.init(args = {})
    if @em_manager.nil?
      @em_manager = EMManager.new
    end

    @em_manager.update args
    @em_manager.start
  end

  # Delegates all methods invoked on calls to EMManager
  def self.method_missing(method_id, *args, &bl)
    @em_manager.send method_id, *args, &bl
  end

end
