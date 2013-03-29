#!/usr/bin/ruby
# launches a series of clients

NUM_CLIENTS = 50
NUM_MSGS    = 50 # per client
NODE_ID     = 'rjr_test_launcher-'
ID_OFFSET   = 100
MSG_IDS     = ['stress', 'stress_callback']
TRANSPORTS  = {:amqp => 'rjr_test_server-queue'}
BROKER      = 'localhost' # only used for amqp
MSG_INTERVAL= 1

CLIENT = File.join(File.dirname(__FILE__), 'client.rb')

threads = []

0.upto(NUM_CLIENTS) { |i|
  transport = TRANSPORTS.keys[rand(TRANSPORTS.keys.size)]
  dst       = TRANSPORTS[transport]
  mode      = rand(2) == 0 ? :msg : :rand
  node_id   = NODE_ID + (i + ID_OFFSET).to_s
  msg_id    = MSG_IDS[rand(MSG_IDS.size)]

  threads <<
    Thread.new{
      system("#{CLIENT} -m #{mode} -t #{transport} -i #{node_id} -b #{BROKER} -n #{NUM_MSGS} --message #{msg_id} --interval #{MSG_INTERVAL}")
    }
}

threads.each { |t| t.join }
