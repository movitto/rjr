module RJRMethods
  @server_stress = lambda { |p|
    RJR::Logger.info "invoked stress method #{p}"
    'foobar'
  }

  @server_stress_callback = lambda { |p|
    RJR::Logger.info "invoked stress_callback method #{p}"
    @rjr_callback.invoke 'stress_callback', p
    'barfoo'
  }

  @client_stress_callback = lambda{ |p|
    RJR::Logger.info "invoked client_callback method #{p}"
    #amqp_node.invoke_request('stress_test-queue', 'stress', "foozmoney#{client_id}")
    #amqp_node.stop
    nil
  }
end
