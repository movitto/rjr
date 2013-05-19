require 'rjr/nodes/web'

server = RJR::Nodes::Web.new :host => 'localhost', :port => 9789, :node_id => "server"
server.dispatcher.handle('method') { |i|
  puts "server: #{i}"
  "#{i}".upcase
}
server.listen

client = RJR::Nodes::Web.new :node_id => "client", :host => 'localhost', :port => 9666
client.notify "http://localhost:9789", "method", "Hello World"
# => nil

client.invoke "http://localhost:9789", "method", "Hello World"
# => HELLO WORLD
#client.join
