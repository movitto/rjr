# Thread Pool (second implementation)
#
# Copyright (C) 2010-2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'singleton'

# Work item to be executed in a thread launched by {ThreadPool}.
#
# The end user just need to initialize this class with the handle
# to the job to be executed and the params to pass to it, before
# handing it off to the thread pool that will take care of the rest.
class ThreadPoolJob
  attr_accessor :handler
  attr_accessor :params

  # used internally by the thread pool system, these shouldn't
  # be set or used by the end user
  attr_accessor :timestamp
  attr_accessor :thread
  attr_accessor :pool_lock
  attr_reader   :being_executed

  # ThreadPoolJob initializer
  # @param [Array] params arguments to pass to the job when it is invoked
  # @param [Callable] block handle to callable object corresponding to job to invoke
  def initialize(*params, &block)
    @params = params
    @handler = block
    @being_executed = false
    @timestamp = nil
  end

  # Return string representation of thread pool job
  def to_s
    "thread_pool_job-#{@handler.source_location}-#{@params}"
  end

  def being_executed?
    @being_executed
  end

  def completed?
    !@timestamp.nil? && !@being_executed
  end

  # Set job metadata and execute job with specified params
  def exec
    # synchronized so that both timestamp is set and being_executed
    # set to true before the possiblity of a timeout management
    # check (see handle_timeout! below)
    @pool_lock.synchronize{
      @thread = Thread.current
      @being_executed = true
      @timestamp = Time.now
    }

    @handler.call *@params

    # synchronized so as to ensure that a timeout check does not
    # occur until before (in which case thread is killed during
    # the check as one atomic operation) or after (in which case
    # job is marked as completed, and thread is not killed / goes
    # onto pull anther job)
    @pool_lock.synchronize{
      @being_executed = false
    }
  end

  # Check timeout and kill thread if it exceeded.
  def handle_timeout!(timeout)
    # Synchronized so that check and kill operation occur as an
    # atomic operation, see exec above
    @pool_lock.synchronize { 
      if @being_executed && (Time.now - @timestamp) > timeout
        RJR::Logger.debug "timeout detected on thread #{@thread} started at #{@timestamp}"
        @thread.kill
        return true
      end
      return false
    }
  end
end

# Utility to launches a specified number of threads on instantiation,
# assigning work to them in order as it arrives.
#
# Supports optional timeout which allows the developer to kill and restart
# threads if a job is taking too long to run.
#
# Second (and hopefully better) thread pool implementation.
#
# TODO move to the RJR namespace
class ThreadPool
  private

  # Internal helper, launch worker thread
  #
  # Should only be launched from within the pool_lock
  def launch_worker
    @worker_threads << Thread.new {
      while work = @work_queue.pop
        begin
          #RJR::Logger.debug "launch thread pool job #{work}"
          work.pool_lock = @pool_lock
          @running_queue << work
          work.exec
          # TODO cleaner / more immediate way to pop item off running_queue
          #RJR::Logger.debug "finished thread pool job #{work}"
        rescue Exception => e
          # FIXME also send to rjr logger at a critical level
          puts "Thread raised Fatal Exception #{e}"
          puts "\n#{e.backtrace.join("\n")}"
        end
      end
    } unless @worker_threads.size == @num_threads
  end

  # Internal helper, performs checks on workers
  def check_workers
    if @terminate
      @pool_lock.synchronize { 
        @worker_threads.each { |t| 
          t.kill
        }
        @worker_threads = []
      }

    elsif @timeout
      readd = []
      while @running_queue.size > 0 && work = @running_queue.pop
        if @timeout && work.handle_timeout!(@timeout)
          @pool_lock.synchronize { 
            @worker_threads.delete(work.thread)
            launch_worker
          }
        elsif !work.completed?
          readd << work
        end
      end
      readd.each { |work| @running_queue << work }
    end
  end

  # Internal helper, launch management thread
  #
  # Should only be launched from within the pool_lock
  def launch_manager
    @manager_thread = Thread.new {
      until @terminate
        # sleep needs to occur b4 check workers so
        # workers are guaranteed to be terminated on @terminate
        # !FIXME! this enforces a mandatory setting of @timeout which was never intended:
        sleep @timeout
        check_workers
      end
      check_workers
      @pool_lock.synchronize { @manager_thread = nil }
    } unless @manager_thread
  end

  public
  # Create a thread pool with a specified number of threads
  # @param [Integer] num_threads the number of worker threads to create
  # @param [Hash] args optional arguments to initialize thread pool with
  # @option args [Integer] :timeout optional timeout to use to kill long running worker jobs
  def initialize(num_threads, args = {})
    @work_queue  = Queue.new
    @running_queue  = Queue.new

    @num_threads = num_threads
    @pool_lock = Mutex.new
    @worker_threads = []

    @timeout     = args[:timeout]

    ObjectSpace.define_finalizer(self, self.class.finalize(self))
  end

  # Return internal thread pool state in string
  def inspect
    "wq#{@work_queue.size}/\
rq#{@running_queue.size}/\
nt#{@num_threads.size}/\
wt#{@worker_threads.select { |wt| ['sleep', 'run'].include?(wt.status) }.size}ok-\
#{@worker_threads.select { |wt| ['aborting', false, nil].include?(wt.status) }.size}nok/\
to#{@timeout}"
  end

  # Start the thread pool
  def start
    # clear work and timeout queues?
    @pool_lock.synchronize {
      @terminate = false
      launch_manager
      0.upto(@num_threads) { |i| launch_worker }
    }
  end

  # Ruby ObjectSpace finalizer to ensure that thread pool terminates all
  # threads when object is destroyed
  def self.finalize(thread_pool)
    proc { thread_pool.stop ; thread_pool.join }
  end

  # Return boolean indicating if thread pool is running.
  #
  # If at least one worker thread isn't terminated, the pool is still considered running
  def running?
    @pool_lock.synchronize { @worker_threads.size != 0 && @worker_threads.all? { |t| t.status } }
  end

  # Add work to the pool
  # @param [ThreadPoolJob] work job to execute in first available thread
  def <<(work)
    # TODO option to increase worker threads if work queue gets saturated
    @work_queue.push work
  end

  # Terminate the thread pool, stopping all worker threads
  def stop
    @pool_lock.synchronize {
      @terminate = true

      # wakeup management thread so it can kill workers
      # before terminating on its own
      begin
        @manager_thread.wakeup

      # incase thread wakes up / terminates on its own
      rescue ThreadError

      end
    }
    join
  end

  # Block until all worker threads have finished executing
  def join
    #@pool_lock.synchronize { @worker_threads.each { |t| t.join unless @terminate } }
    th = nil
    @pool_lock.synchronize { th = @manager_thread if @manager_thread }
    th.join if th
  end
end

# Providers an interface to access a shared thread pool.
#
# Thread pool operations may be invoked on this class after
# the 'init' method is called
#
#     ThreadPoolManager.init
#     ThreadPoolManager << ThreadPoolJob(:foo) { "do something" }
class ThreadPoolManager
  # Initialize thread pool if it doesn't exist
  def self.init(num_threads, params = {})
    if @thread_pool.nil?
      @thread_pool = ThreadPool.new(num_threads, params)
    end
    @thread_pool.start
  end

  # Return shared thread pool
  def self.thread_pool
    @thread_pool
  end

  # Delegates all methods invoked on calls to thread pool
  def self.method_missing(method_id, *args, &bl)
    @thread_pool.send method_id, *args, &bl
  end
end
