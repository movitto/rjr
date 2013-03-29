#!/usr/bin/ruby
# RJR test harness server

require 'rubygems'
require 'rjr'

require 'common'

##########################################################

NODES = {:amqp  =>  {:node_id => 'rjr_test_server', :broker => 'localhost'},
         :ws    =>  {:node_id => 'rjr_test_server', :host   => 'localhost', :port => 8080},
         :www   =>  {:node_id => 'rjr_test_server', :host   => 'localhost', :port => 8888},
         :tcp   =>  {:node_id => 'rjr_test_server', :host   => 'localhost', :port => 8181}}

METHODS_DIR = File.join(File.dirname(__FILE__), 'methods')

##########################################################

RJR::Logger.log_level = ::Logger::DEBUG
RJRMethods.load(METHODS_DIR, 'server_')
RJRNode.new(NODES).stop_on("INT").listen.join
