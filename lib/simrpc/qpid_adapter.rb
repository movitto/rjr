# simrpc message module
#
# Copyright (C) 2010 Mohammed Morsi <movitto@yahoo.com>
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

require 'qpid'
require 'socket'
require 'semaphore'

module Simrpc

# The QpidAdapter module implements the simrpc qpid subsystem, providing
# a convenient way to access qpid constructs
module QpidAdapter

# Simrpc::Qpid::Node class, represents an enpoint  on a qpid
# network which has its own exchange and queue which it listens on
class Node
 private
  # helper method to generate a random id
  def gen_uuid
    ["%02x"*4, "%02x"*2, "%02x"*2, "%02x"*2, "%02x"*6].join("-") %
        Array.new(16) {|x| rand(0xff) }
  end

 public
  # a node can have children nodes mapped to by keys
  attr_accessor :children

  # node always has a node id
  attr_reader :node_id

  # create the qpid base connection with the specified broker / port
  # or config file. Then establish exchange and queue and start listening
  # for requests.
  #
  # specify :broker and :port arguments to directly connect to those
  # specify :config argument to use that yml file
  # specify MOTEL_AMQP_CONF environment variable to use that yml file
  # specify :id parameter to set id, else it will be set to a uuid just created
  def initialize(args = {})
     # if no id specified generate a new uuid
     @node_id = args[:id].nil? ? gen_uuid : args[:id]

     # we generate a random session id
     @session_id = gen_uuid

     # get the broker/port
     broker = args[:broker].nil? ? "localhost"  : args[:broker]
     port   = args[:port].nil? ? 5672  : args[:port]

     if (broker.nil? || port.nil?) && args.has_key?(:config)
       config      =
       amqpconfig = YAML::load(File.open(args[:config]))
       broker = amqpconfig["broker"] if broker.nil?
       port   = amqpconfig["port"]   if port.nil?
     end

     ### create underlying tcp connection
     @conn = Qpid::Connection.new(TCPSocket.new(broker,port))
     @conn.start

     ### connect to qpid broker
     @ssn = @conn.session(@session_id)

     @children = {}

     @accept_lock = Semaphore.new(1)

     # qpid constructs that will be created for node
     @exchange     = args[:exchange].nil?    ? @node_id.to_s + "-exchange"    : args[:exchange]
     @queue        = args[:queue].nil?       ? @node_id.to_s + "-queue"       : args[:queue]
     @local_queue  = args[:local_queue].nil? ? @node_id.to_s + "-local-queue" : args[:local_queue]
     @routing_key  = @queue

     Logger.warn "creating qpid exchange #{@exchange} queue #{@queue} binding_key #{@routing_key}"

     if @ssn.exchange_query(@exchange).not_found
       @ssn.exchange_declare(@exchange, :type => "direct")
     end

     if @ssn.queue_query(@queue).queue.nil?
       @ssn.queue_declare(@queue)
     end

     @ssn.exchange_bind(:exchange => @exchange,
                        :queue    => @queue,
                        :binding_key => @routing_key)
  end

  # Instruct Node to start accepting requests asynchronously and immediately return.
  # handler must be callable and take node, msg, respond_to arguments, corresponding to
  # 'self', the message received', and the routing_key which to send any response.
  def async_accept(&handler)
     # TODO permit a QpidNode to accept messages from multiple exchanges/queues
     @accept_lock.wait

     # subscribe to the queue
     @ssn.message_subscribe(:destination => @local_queue,
                            :queue => @queue,
                            :accept_mode => @ssn.message_accept_mode.none)
     @incoming = @ssn.incoming(@local_queue)
     @incoming.start

     Logger.warn "listening for messages on #{@queue}"

     # start receiving messages
     @incoming.listen{ |msg|
        Logger.info "queue #{@queue} received message #{msg.body}"
        reply_to = msg.get(:message_properties).reply_to.routing_key
        handler.call(self, msg.body, reply_to)
     }
  end

  # block until accept operation is complete
  def join
     @accept_lock.wait
  end

  # instructs QpidServer to stop accepting, blocking
  # untill all accepting operations have terminated
  def terminate
    Logger.warn "terminating qpid session"
    unless @incoming.nil?
      @incoming.stop
      @incoming.close
      @accept_lock.signal
    end
    @ssn.close
    # TODO undefine the @queue/@exchange
  end

  # send a message to the specified routing_key
  def send_message(routing_key, message)
    dp = @ssn.delivery_properties(:routing_key => routing_key)
    mp = @ssn.message_properties( :content_type => "text/plain")
    rp = @ssn.message_properties( :reply_to =>
                                  @ssn.reply_to(@exchange, @routing_key))
    msg = Qpid::Message.new(dp, mp, rp, message.to_s)

    Logger.warn "sending qpid message #{msg.body} to #{routing_key}"

    # send it
    @ssn.message_transfer(:message => msg)
  end

end

end # module QpidAdapter

end # module Simrpc
