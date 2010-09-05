# Thread Pool
#
# Copyright (C) 2010 Mohammed Morsi <movitto@yahoo.com>
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

require 'thread'

module Simrpc

  # Work item to be executed in thread pool
  class ThreadPoolJob
    attr_accessor :handler
    attr_accessor :params

    def initialize(*params, &block)
      @params = params
      @handler = block
    end
  end

  # ActiveObject pattern, encapsulate each thread pool thread in object
  class ThreadPoolJobRunner
    attr_accessor :time_started

    def initialize(thread_pool)
      @thread_pool = thread_pool
    end

    def run
      @thread = Thread.new {
        until @thread_pool.terminate
          work = @thread_pool.next_job
          @time_started = Time.now
          work.handler.call *work.params unless work.nil?
          @time_started = nil
        end
      }
    end

    def stop
      @thread.kill
      @thread.join
    end

    def join
      @thread.join
    end
  end

  # Launches a specified number of threads on instantiation,
  # assigning work to them as it arrives
  class ThreadPool
    attr_accessor :terminate

    # Create a thread pool with a specified number of threads
    def initialize(num_threads, args = {})
      @num_threads = num_threads
      @timeout     = args[:timeout]
      @job_runners = []
      @work_queue  = []
      @work_queue_lock = Mutex.new
      @work_queue_cv = ConditionVariable.new

      @terminate = false

      0.upto(@num_threads) { |i| 
        runner = ThreadPoolJobRunner.new(self)
        @job_runners << runner
        runner.run
      }

      # optional timeout thread
      unless @timeout.nil?
        @timeout_thread = Thread.new {
          until @terminate
            sleep @timeout
            @job_runners.each { |jr|
              if !jr.time_started.nil? && (Time.now - jr.time_started > @timeout)
                jr.stop
                jr.run
              end
            }
          end
        }
      end
    end

    # Add work to the pool
    def <<(work)
      @work_queue_lock.synchronize {
        @work_queue << work
        @work_queue_cv.signal
      }
    end

    # Return the next job queued up, blocking until one is received 
    # if none are present
    def next_job
      work = nil
      @work_queue_lock.synchronize {
        # wait until we have work
        @work_queue_cv.wait(@work_queue_lock) if @work_queue.empty?
        work = @work_queue.shift
      }
      work
    end

    # Terminate the thread pool
    def stop
      @terminate = true
      @work_queue_lock.synchronize {
        @work_queue.clear
      }
      @job_runners.each { |jr| jr.stop }
    end
  end
end
