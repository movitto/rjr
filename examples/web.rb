#!/usr/bin/ruby
# A RJR web-node example
#
# Copyright (C) 2013 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'rjr/nodes/web'

server = RJR::Nodes::Web.new :host => 'localhost', :port => 9789, :node_id => "server"

server.dispatcher.handle('method') { |i|
  puts "server: #{i}"
  "#{i}".upcase
}

# Add handler with named params
server.dispatcher.handle('named') { |login, password|
  puts "login -> #{login}\n" \
       "pass -> #{password}"
}

server.listen

client = RJR::Nodes::Web.new :node_id => "client", :host => 'localhost', :port => 9666
client.notify "http://localhost:9789", "method", "Hello World"
# => nil

client.invoke "http://localhost:9789", "method", "Hello World"
# => HELLO WORLD

client.invoke 'http://localhost:9789', 'named', '{"login": "user_login", "password": "user_pass"}'
#client.join
