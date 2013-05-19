#!/usr/bin/ruby
# A RJR tcp-node example
#
# Copyright (C) 2013 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'rjr/nodes/tcp'

server = RJR::Nodes::TCP.new :host => 'localhost', :port => 9789, :node_id => "server"
server.dispatcher.handle('method') { |i|
  puts "server: #{i}"
  @rjr_callback.notify "callback", i.downcase
  "#{i}".upcase
}
server.listen

client = RJR::Nodes::TCP.new :node_id => "client", :host => 'localhost', :port => 9666
client.dispatcher.handle('callback') { |i|
  puts "callback: #{i}"
  #client.halt
}

client.notify "jsonrpc://localhost:9789", "method", "Hello World"
# => nil

client.invoke "jsonrpc://localhost:9789", "method", "Hello World"
# => HELLO WORLD

#client.join
