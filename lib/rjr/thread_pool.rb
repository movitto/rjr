# Thread Pool
#
# Copyright (C) 2010-2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

# Work item to be executed in a thread launched by pool
class ThreadPoolJob
  attr_accessor :handler
  attr_accessor :params

  # ThreadPoolJob initializer
  # @param [Array] params arguments to pass to the job when it is invoked
  # @param [Callable] block handle to callable object corresponding to job to invoke
  def initialize(*params, &block)
    @params = params
    @handler = block
  end
end


# Utility to launches a specified number of threads on instantiation,
# assigning work to them in order as it arrives.
#
# Supports optional timeout which allows the developer to kill and restart
# threads if a job is taking too long to run.
class ThreadPool

  # @private
  # Helper class to encapsulate each thread pool thread
  class ThreadPoolJobRunner
    attr_accessor :time_started

    def initialize(thread_pool)
      @thread_pool = thread_pool
      @timeout_lock = Mutex.new
      @thread_lock  = Mutex.new
    end

    # Start thread and pull a work items off the thread pool work queue and execute them.
    #
    # This method will return immediately after the worker thread is started but the
    # thread launched will persist until {#stop} is invoked
    def run
      @thread_lock.synchronize {
        @thread = Thread.new {
          until @thread_pool.terminate
            @timeout_lock.synchronize { @time_started = nil }
            work = @thread_pool.next_job
            @timeout_lock.synchronize { @time_started = Time.now }
            unless work.nil?
              begin
                work.handler.call *work.params
              rescue Exception => e
                puts "Thread raised Fatal Exception #{e}"
                puts "\n#{e.backtrace.join("\n")}"
              end
            end
          end
        }
      }
    end

    # Return boolean indicating if worker thread is running or not
    def running?
      res = nil
      @thread_lock.synchronize{
        res = (!@thread.nil? && (@thread.status != false))
      }
      res
    end

    # Return boolean indicating if worker thread run time has exceeded timeout
    # Should not invoke after stop is called
    def check_timeout(timeout)
      @timeout_lock.synchronize {
        if !@time_started.nil? && Time.now - @time_started > timeout
          stop
          run
        end
      }
    end

    # Stop the worker thread being executed
    def stop
      @thread_lock.synchronize {
        if @thread.alive?
          @thread.kill
          @thread.join
        end
        @thread = nil
      }
    end

    # Block until the worker thread is finished
    def join
      @thread_lock.synchronize {
        @thread.join unless @thread.nil?
      }
    end
  end

  # Create a thread pool with a specified number of threads
  # @param [Integer] num_threads the number of worker threads to create
  # @param [Hash] args optional arguments to initialize thread pool with
  # @option args [Integer] :timeout optional timeout to use to kill long running worker jobs
  def initialize(num_threads, args = {})
    @num_threads = num_threads
    @timeout     = args[:timeout]
    @job_runners = []
    @job_runners_lock = Mutex.new
    @terminate = false
    @terminate_lock = Mutex.new

    @work_queue  = Queue.new

    0.upto(@num_threads) { |i| 
      runner = ThreadPoolJobRunner.new(self)
      @job_runners << runner
      runner.run
    }

    # optional timeout thread
    unless @timeout.nil?
      @timeout_thread = Thread.new {
        until terminate
          sleep @timeout
          @job_runners_lock.synchronize {
            @job_runners.each { |jr|
              jr.check_timeout(@timeout)
            }
          }
        end
      }
    end
  end

  # Return boolean indicated if thread pool is running.
  #
  # If at least one worker thread isn't terminated, the pool is still considered running
  def running?
    !terminate && (@timeout.nil? || (!@timeout_thread.nil? && @timeout_thread.status)) &&
    @job_runners.all? { |r| r.running? }
  end

  # Return boolean indicating if the thread pool should be terminated
  def terminate
    @terminate_lock.synchronize { @terminate }
  end

  # Instruct thread pool to terminate
  # @param [Boolean] val true/false indicating if thread pool should terminate
  def terminate=(val)
    @terminate_lock.synchronize { @terminate = val }
  end

  # Add work to the pool
  # @param [ThreadPoolJob] work job to execute in first available thread
  def <<(work)
    @work_queue.push work
  end

  # Return the next job queued up and remove it from the queue
  def next_job
    @work_queue.pop
  end

  # Terminate the thread pool, stopping all worker threads
  def stop
    terminate = true
    unless @timout_thread.nil?
      @timeout_thread.join
      @timeout_thread.terminate
    end
    @timeout_thread = nil
    @work_queue.clear
    @job_runners_lock.synchronize { @job_runners.each { |jr| jr.stop } }
  end

  # Block until all worker threads have finished executing
  def join
    @job_runners_lock.synchronize { @job_runners.each { |jr| jr.join } }
  end
end

