# default module loaded w/ bin/rjr-server

def dispatch_server(dispatcher)
  dispatcher.handle "messages" do |p|
    $messages.string.split("\n")
  end

  dispatcher.handle "failed" do |p|
    RJR::Logger.info "invoked failed method #{p}"
   raise ArgumentError, "err #{p}"
  end

  dispatcher.handle "stress" do |p|
    RJR::Logger.info "invoked stress method #{p}"
   "foobar #{p}"
  end

  dispatcher.handle "stress_callback" do |p|
    RJR::Logger.info "invoked stress_callback method #{p}"
    @rjr_callback.notify 'client_callback', p
    "barfoo #{p}"
  end
end
