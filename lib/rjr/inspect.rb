# JSON-RPC method definitions providing access to inspect the internal
# node state.
#
# Note this isn't included in the top level rjr module by default,
# manually include this module to incorporate these additional rjr method
# definitions into your node
#
# Copyright (C) 2013 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'rjr/util'
include RJR::Definitions

# Helper method to process user params / select stats
def select_stats(*filter)
  lf = []
  while q = filter.shift
    lf << 
      case q
      when 'on_node'    then
        n = filter.shift 
        lambda { |ds| ds.request.rjr_node_type.to_s == n}

      when "for_method" then
        m = filter.shift
        lambda { |ds| ds.request.rjr_method == m}

      when 'successful' then
        lambda { |ds| ds.result.success }

      when 'failed'     then
        lambda { |ds| ds.result.failed  }

      end
  end

  RJR::DispatcherStat.stats.select { |ds| lf.all? { |lfi| lfi.call(ds) } }
end
 
rjr_method \
  "rjr::dispatches" =>
    # Retrieve all the dispatches this node served matching the specified criteri
    lambda { |*filter| select_stats(*filter) },

  "rjr::num_dispatches" =>
    # Retrieve the number of dispatches this node served matching the specified criteria
    lambda { |*filter| select_stats(*filter).size },

  "rjr::status" =>
    # Retrieve the overall status of this node
    lambda {
      {
        # event machine
        :event_machine => { :running => EMAdapter.running?,
                            :thread_status => EMAdapter.reactor_thread.status,
                            :connections => EventMachine.connection_count },

        # thread pool
        :thread_pool => { :running => ThreadPoolManager.thread_pool.running?,
                          :inspect => ThreadPoolManager.thread_pool.inspect },
      }
    }

  #:log =>
  #  lambda {},
