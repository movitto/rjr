#!/usr/bin/ruby
# A RJR unix-node example
#
# Copyright (C) 2013 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'rjr/nodes/unix'

server = RJR::Nodes::Unix.new :socketname => './server.sock', :node_id => "server"
server.dispatcher.handle('method') { |i|
  puts "server: #{i}"
  @rjr_callback.notify "callback", i.downcase
  "#{i}".upcase
}
server.listen

client = RJR::Nodes::Unix.new :node_id => "client"
client.dispatcher.handle('callback') { |i|
  puts "callback: #{i}"
  #client.halt
}

client.notify "./server.sock", "method", "Hello World"
# => nil

client.invoke "./server.sock", "method", "Hello World"
# => HELLO WORLD

#client.join
