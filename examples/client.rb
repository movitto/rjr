# default client definitions loaded by bin/rjr-client
#
# Copyright (C) 2013 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'rjr/util/has_messages'

include RJR::HasMessages

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

def dispatch_examples_client(dispatcher)
  dispatcher.handle "client_callback" do |p|
    RJR::Logger.info "invoked client_callback method #{p}"
    #amqp_node.invoke_request('stress_test-queue', 'stress', "foozmoney#{client_id}")
    #amqp_node.stop
    nil
  end
end
