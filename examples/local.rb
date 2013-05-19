#!/usr/bin/ruby
# A RJR local-node example
#
# Copyright (C) 2013 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0
require 'rjr/nodes/local'

server = RJR::Nodes::Local.new
server.dispatcher.handle('method') { |i|
  puts "server: #{i}"
  @rjr_callback.notify "callback", i.downcase
  "#{i}".upcase
}
server.listen

# local dispatches to whatever methods are registered at hand
client = RJR::Nodes::Local.new :dispatcher => server.dispatcher
client.dispatcher.handle('callback') { |i|
  puts "callback: #{i}"
  #client.halt
}

client.notify "method", "Hello World"
# => nil

puts client.invoke "method", "Hello World"
# => HELLO WORLD

#client.join
