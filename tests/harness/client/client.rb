require 'rjr/util'
include RJR::Definitions

rjr_method \
  :client_callback =>
    lambda{ |p|
      RJR::Logger.info "invoked client_callback method #{p}"
      #amqp_node.invoke_request('stress_test-queue', 'stress', "foozmoney#{client_id}")
      #amqp_node.stop
      nil
    }

rjr_message \
  :stress =>
    { :method => 'stress',
      :params => ["<CLIENT_ID>"],
      :result => lambda { |r| r == 'foobar' } },

  :stress_callback =>
    { :method => 'stress_callback',
      :params => ["<CLIENT_ID>"],
      :transports => [:tcp, :ws, :amqp],
      :result => lambda { |r| r == 'barfoo' } },

  :messages => { :method => 'messages'}
