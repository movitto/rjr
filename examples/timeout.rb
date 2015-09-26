#!/usr/bin/ruby
# A RJR timeout example
#
# Copyright (C) 2015 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'rjr/nodes/tcp'

server = RJR::Nodes::TCP.new :host => 'localhost', :port => 9789, :node_id => "server"
server.dispatcher.handle('method') { |i|
  sleep 2
}
server.listen

client = RJR::Nodes::TCP.new :node_id => "client",
                             :host    => 'localhost',
                             :port    => 9666,
                             :timeout => 1 # causes error, change to 3 to wait for server response

client.invoke "jsonrpc://localhost:9789", "method", "Hello World"
# => exception

#client.join
