# JSON-RPC method definitions providing access to inspect the internal
# node state.
#
# Note this isn't included in the top level rjr module by default,
# manually include this module to incorporate these additional rjr method
# definitions into your node
#
# Copyright (C) 2013 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'eventmachine'

# Helper method to process user params / select stats
# from a dispatcher
def select_stats(dispatcher, *filter)
  lf = []
  while q = filter.shift
    lf << 
      case q
      when 'on_node'    then
        n = filter.shift 
        lambda { |req| req.rjr_node_type.to_s == n}

      when "for_method" then
        m = filter.shift
        lambda { |req| req.rjr_method == m}

      when 'successful' then
        lambda { |req| req.result.success }

      when 'failed'     then
        lambda { |req| req.result.failed  }

      end
  end

  dispatcher.requests.select { |ds| lf.all? { |lfi| lfi.call(ds) } }
end

# Add stats methods to specified dispatcher
def dispatch_stats(dispatcher)
  # Retrieve all the dispatches this node served matching the specified criteri
  dispatcher.handle "rjr::dispatches" do |filter|
    select_stats(*filter) 
  end

  # Retrieve the number of dispatches this node served matching the specified criteria
  dispatcher.handle "rjr::num_dispatches" do |filter|
    select_stats(*filter).size
  end

  # Retrieve the internal status of this node
  dispatcher.handle "rjr::status" do
    {
      # event machine
      :event_machine => { :running => EventMachine.reactor_running?,
                          :thread_status => "TODO",
                          :connections => EventMachine.connection_count },

      # thread pool
      :thread_pool => { :running => "TODO",
                        :inspect => "TODO" },
    }
  end

  #:log =>
  #  lambda {},
end

