# RJR Node Callback
#
# Copyright (C) 2012-2014 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

module RJR

# Node callback interface, used to invoke json-rpc
# methods against a remote node via node connection
# previously established
#
# After a node sends a json-rpc request to another,
# the either node may send additional requests to
# each other via the connection already established
# until it is closed on either end
class NodeCallback
  attr_reader :node
  attr_reader :connection

  # NodeCallback initializer
  # @param [Hash] args the options to create the node callback with
  # @option args [node] :node node used to send messages
  # @option args [connection] :connection connection to be used in
  #   channel selection
  def initialize(args = {})
    @node        = args[:node]
    @connection  = args[:connection]
  end

  def notify(callback_method, *data)
    # TODO throw error here ?
    return unless node.persistent?

    msg = Messages::Notification.new :method  => callback_method,
                                     :args    => data,
                                     :headers => @node.message_headers

    # TODO surround w/ begin/rescue block,
    # raise RJR::ConnectionError on socket errors
    @node.send_msg msg.to_s, @connection
  end
end # class NodeCallback
end # module RJR
