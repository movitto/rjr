# EventMachine Adapter
#
# Copyright (C) 2012-2013 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'eventmachine'

module RJR

# EventMachine adapater interface, ties reactor
# lifecycle to an instance of this class.
class EMAdapter
  # Run reactor in its own interally managed thread
  attr_accessor :reactor_thread

  # EMAdapter initializer
  def initialize
    @em_lock = Mutex.new

    EventMachine.error_handler { |e|
      puts "EventMachine raised critical error #{e} #{e.backtrace}"
      # TODO dispatch to registered event handlers
    }
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
          @em_lock.synchronize { @reactor_thread = nil }
        end
      } unless @reactor_thread
    }
    sleep 0.01 until EventMachine.reactor_running? # XXX hack but needed
    self
  end

  # Halt the reactor if running
  #
  # @return self
  def halt
    EventMachine.stop_event_loop if EventMachine.reactor_running?
    self
  end

  # Block until reactor thread is terminated
  #
  # @return self
  def join
    th = @em_lock.synchronize{ @reactor_thread }
    th.join unless th.nil?
    self
  end

  # Delegates everything else directly to eventmachine
  #   (eg schedule, add_timer, add_periodic_timer,
  #       reactor_running?, stop_event_loop, etc)
  def method_missing(method_id, *args, &bl)
    @em_lock.synchronize{
      EventMachine.send method_id, *args, &bl
    }
  end
end

end # module RJR
