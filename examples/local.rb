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
