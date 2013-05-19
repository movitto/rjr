require 'rjr/nodes/ws'

server = RJR::Nodes::WS.new :host => 'localhost', :port => 9789, :node_id => "server"
server.dispatcher.handle('method') { |i|
  puts "server: #{i}"
  @rjr_callback.notify "callback", i.downcase
  "#{i}".upcase
}
server.listen

client = RJR::Nodes::WS.new :node_id => "client", :host => 'localhost', :port => 9666
client.dispatcher.handle('callback') { |i|
  puts "callback: #{i}"
  #client.halt
}

client.notify "ws://localhost:9789", "method", "Hello World"
# => nil

client.invoke "ws://localhost:9789", "method", "Hello World"
# => HELLO WORLD

#client.join
