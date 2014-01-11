# JSON-RPC method definitions providing access to inspect the internal
# node state.
#
# Note this isn't included in the top level rjr module by default,
# manually include this module to incorporate these additional rjr method
# definitions into your node
#
# Note by default RJR will _not_ keep persistant copies or requests
# and responses. If available these are leveraged here to provide
# a detailed analysis of the server. To enabled set the 'keep_requests'
# flag on your RJR::Dispatcher instance to true
#
# Copyright (C) 2013 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

# TODO
# - data received/sent (on different interfaces)
# - messages received/sent (on different interfaces)
# - dispatches on a per node basis
# - unresolved/invalid dispatches/messages
# - em jobs
# - thread pool jobs (started / completed / etc)

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

# Add inspection methods to specified dispatcher
def dispatch_rjr_inspect(dispatcher)
  # Retrieve all the dispatches this node served matching the specified criteri
  dispatcher.handle "rjr::dispatches" do |filter|
    select_stats(dispatcher, *filter) 
  end

  # Retrieve the number of dispatches this node served matching the specified criteria
  dispatcher.handle "rjr::num_dispatches" do |filter|
    select_stats(dispatcher, *filter).size
  end

  # Retrieve the internal status of this node
  dispatcher.handle "rjr::status" do
    nodes = []
    ObjectSpace.each_object RJR::Node do |node|
      nodes << node.to_s
    end

    {
      # nodes
      :nodes => nodes,

      # dispatcher
      :dispatcher => {
        :requests => dispatcher.requests.size,
        :handlers =>
          dispatcher.handlers.keys,
          #dispatcher.handlers.collect { |k,v|
          #  [k, v.source_location] },
        :environments => dispatcher.environments
      },

      # event machine
      :event_machine => { :running => EventMachine.reactor_running?,
                          :thread_status =>
                           (RJR::Node.em && RJR::Node.em.reactor_thread) ?
                                RJR::Node.em.reactor_thread.status : nil,
                          :connections => EventMachine.connection_count },

      # thread pool
      :thread_pool => { :running => RJR::Node.tp ? RJR::Node.tp.running? : nil }
    }
  end

  #:log =>
  #  lambda {},
end
