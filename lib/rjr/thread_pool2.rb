# Thread Pool (second implementation)
#
# Copyright (C) 2010-2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'singleton'

# Work item to be executed in a thread launched by {ThreadPool2}
class ThreadPool2Job
  attr_accessor :handler
  attr_accessor :params
  attr_accessor :timestamp
  attr_accessor :thread

  attr_accessor :metadata_lock

  # ThreadPoolJob initializer
  # @param [Array] params arguments to pass to the job when it is invoked
  # @param [Callable] block handle to callable object corresponding to job to invoke
  def initialize(*params, &block)
    @params = params
    @handler = block
    @being_executed = false
  end

  def to_s
    "thread_pool2_job-#{@handler.source_location}-#{@params}"
  end

  def being_executed?
    @being_executed
  end

  def exec
    @metadata_lock.synchronize{
      @thread = Thread.current
      @timestamp = Time.now
      @being_executed = true
    }

    @handler.call @params

    @metadata_lock.synchronize{
      @being_executed = false
    }
  end

  def handle_timeout!(timeout)
    @metadata_lock.synchronize{
      if @being_executed && (Time.now - @timestamp) > timeout
        RJR::Logger.debug "timeout detected on thread #{@thread}"
        @thread.kill
        return true
      end
    }
    return false
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
class ThreadPool2
  private

  # Internal helper, launch worker thread
  def launch_worker
    @pool_lock.synchronize{
      @worker_threads << Thread.new {
        while work = @work_queue.pop
          begin
            #RJR::Logger.debug "launch thread pool job #{work}"
            work.metadata_lock = @pool_lock
            @running_queue << work
            work.exec
            #RJR::Logger.debug "finished thread pool job #{work}"
          rescue Exception => e
            puts "Thread raised Fatal Exception #{e}"
            puts "\n#{e.backtrace.join("\n")}"
          end
        end
      } unless @worker_threads.size == @num_threads
    }
  end

  # Internal helper, kill specified worker
  def stop_worker(old_worker)
    @pool_lock.synchronize { old_worker.kill ; @worker_threads.delete(old_worker) }
  end

  # Internal helper, kill/restart specified worker
  def relaunch_worker(old_worker)
    stop_worker(old_worker)
    launch_worker
  end

  # Internal helper, performs checks on workers
  def check_workers
    if @terminate
      @worker_threads.each { |t| stop_worker(t) }

    elsif @timeout
      readd = []
      while @running_queue.size > 0 && to = @running_queue.pop
        if @timeout && to.handle_timeout!(@timeout)
          launch_worker
        else
          readd << to
        end
      end
      readd.each { @running_queue << to }
    end

  end

  # Internal helper, launch management thread
  def launch_manager
    @pool_lock.synchronize {
      @manager_thread = Thread.new {
        until @terminate
          # sleep needs to occur b4 check workers so
          # workers are guaranteed to be terminated on @terminate
          sleep @timeout
          check_workers
        end
        @pool_lock.synchronize { @manager_thread = nil }
      } unless @manager_thread
    }
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

  # Start the thread pool
  def start
    # clear work and timeout queues?
    @pool_lock.synchronize { @terminate = false }
    launch_manager
    0.upto(@num_threads) { |i| launch_worker }
  end

  # Ruby ObjectSpace finalizer to ensure that thread pool terminates all
  # threads when object is destroyed
  def self.finalize(thread_pool)
    proc { thread_pool.stop ; thread_pool.join }
  end

  # Return boolean indicated if thread pool is running.
  #
  # If at least one worker thread isn't terminated, the pool is still considered running
  def running?
    @pool_lock.synchronize { @worker_threads.all? { |t| t.status } }
  end

  # Add work to the pool
  # @param [ThreadPool2Job] work job to execute in first available thread
  def <<(work)
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
    # TODO protect w/ pool_lock? (causes deadlock)
    @manager_thread.join if @manager_thread
  end
end

# Providers an interface to access a shared thread pool.
#
# Thread pool operations may be invoked on this class after
# the 'init' method is called
#
#     ThreadPool2Manager.init
#     ThreadPool2Manager << ThreadPool2Job(:foo) { "do something" }
class ThreadPool2Manager
  # Initialize thread pool if it doesn't exist
  def self.init(num_threads, params = {})
    if @thread_pool.nil?
      @thread_pool = ThreadPool2.new(num_threads, params)
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
