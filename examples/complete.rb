#!/usr/bin/ruby
# A RJR multi-node example
#
# Copyright (C) 2013 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'rjr/nodes/amqp'
require 'rjr/nodes/tcp'
require 'rjr/nodes/ws'
require 'rjr/nodes/web'
require 'rjr/nodes/local'
require 'rjr/nodes/multi'
require 'rjr/nodes/easy'

server1 = RJR::Nodes::AMQP.new :node_id => 'server', :broker => 'localhost'
server2 = RJR::Nodes::TCP.new :host => 'localhost', :port => 9789, :node_id => 'server'
server3 = RJR::Nodes::WS.new :host => 'localhost', :port => 9788, :node_id => 'server'
server4 = RJR::Nodes::Web.new :host => 'localhost', :port => 9787, :node_id => 'server'
server5 = RJR::Nodes::Local.new
server = RJR::Nodes::Multi.new :nodes => [server1, server2, server3, server4, server5]
server.dispatcher.handle('method') { |i|
  puts "server: #{i}"
  "#{i}".upcase
}
server.listen

client = RJR::Nodes::Easy.new :node_id => 'client',
                              :tcp  => { :host => 'localhost', :port => 9666 },
                              :ws   => { :host => 'localhost', :port => 9665 },
                              :web  => { :host => 'localhost', :port => 9664},
                              :amqp => { :broker => 'localhost' }

puts client.invoke 'tcp://localhost:9789', 'method', 'Hello World'
puts client.invoke 'http://localhost:9787', 'method', 'Hello World'
puts client.invoke 'ws://localhost:9788', 'method', 'Hello World'
puts client.invoke 'server-queue', 'method', 'Hello World'
