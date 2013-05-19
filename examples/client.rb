# default client definitions loaded in bin/rjr-client

include RJR::MessageMixins

def dispatch_client(dispatcher)
  dispatcher.handle "client_callback" do |p|
    RJR::Logger.info "invoked client_callback method #{p}"
    #amqp_node.invoke_request('stress_test-queue', 'stress', "foozmoney#{client_id}")
    #amqp_node.stop
    nil
  end

  define_message "stress" do
    { :method => 'stress',
      :params => ["<CLIENT_ID>"],
      :result => lambda { |r| r =~ /foobar.*/ } }
  end

  define_message "stress_callback" do
    { :method => 'stress_callback',
      :params => ["<CLIENT_ID>"],
      :transports => [:tcp, :ws, :amqp],
      :result => lambda { |r| r =~ /barfoo.*/ } }
  end

  define_message "messages" do
    { :method => 'messages'}
  end
end
