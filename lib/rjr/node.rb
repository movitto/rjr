# RJR Node
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the AGPLv3+ http://www.gnu.org/licenses/agpl.txt

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

  def initialize(args = {})
     @node_id = args[:node_id]

     @message_headers = {}
     @message_headers.merge!(args[:headers]) if args.has_key?(:headers)

     # threads pool to handle incoming requests
     # FIXME make the # of threads and timeout configurable)
     @thread_pool = ThreadPool.new(10, :timeout => 5)
  end

  # run job in event machine
  def em_run(&bl)
    @@em_jobs ||= 0
    @@em_jobs += 1

    @@em_thread  ||= nil

    if @@em_thread.nil?
      @@em_thread  =
        Thread.new{
          begin
            EventMachine.run
          rescue Exception => e
            puts "Critical exception #{e}"
          ensure
          end
        }
#sleep 0.5 until EventMachine.reactor_running? # XXX hacky way to do this
    end
    EventMachine.schedule bl
  end

  def em_running?
    EventMachine.reactor_running?
  end

  def join
    if @@em_thread
      @@em_thread.join
      @@em_thread = nil
    end
  end

  def stop
    @@em_jobs -= 1
    if @@em_jobs == 0
      EventMachine.stop
      @thread_pool.stop
    end
  end

  def halt
    @@em_jobs = 0
    EventMachine.stop
  end

end
end # module RJR
