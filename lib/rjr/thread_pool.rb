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

# Work item to be executed in thread pool
class ThreadPoolJob
  attr_accessor :handler
  attr_accessor :params

  def initialize(*params, &block)
    @params = params
    @handler = block
  end
end


# Launches a specified number of threads on instantiation,
# assigning work to them as it arrives
class ThreadPool

  # Encapsulate each thread pool thread in object
  class ThreadPoolJobRunner
    attr_accessor :time_started

    def initialize(thread_pool)
      @thread_pool = thread_pool
      @timeout_lock = Mutex.new
      @thread_lock  = Mutex.new
    end

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

    # TODO should not invoke after stop is called
    def check_timeout(timeout)
      @timeout_lock.synchronize {
        if !@time_started.nil? && Time.now - @time_started > timeout
          stop
          run
        end
      }
    end

    def stop
      @thread_lock.synchronize {
        if @thread.alive?
          @thread.kill
          @thread.join
        end
      }
    end
  end

  # Create a thread pool with a specified number of threads
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

  # terminate reader
  def terminate
    @terminate_lock.synchronize { @terminate }
  end

  # terminate setter
  def terminate=(val)
    @terminate_lock.synchronize { @terminate = val }
  end

  # Add work to the pool
  def <<(work)
    @work_queue.push work
  end

  # Return the next job queued up
  def next_job
    @work_queue.pop
  end

  # Terminate the thread pool
  def stop
    terminate = true
    @timeout_thread.join unless @timout_thread.nil?
    @work_queue.clear
    @job_runners_lock.synchronize { @job_runners.each { |jr| jr.stop } }
  end
end

