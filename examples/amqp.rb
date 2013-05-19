require 'rjr/nodes/amqp'

server = RJR::Nodes::AMQP.new :node_id => 'server', :broker => 'localhost'
server.dispatcher.handle('method') { |i|
  puts "server: #{i}"
  @rjr_callback.notify "callback", i.downcase
  "#{i}".upcase
}
server.listen

client = RJR::Nodes::AMQP.new :node_id => "client", :broker => 'localhost'
client.dispatcher.handle('callback') { |i|
  puts "callback: #{i}"
  #client.halt
}

client.notify "server-queue", "method", "Hello World"
# => nil

client.invoke "server-queue", "method", "Hello World"
# => HELLO WORLD

#client.join
