# RJR Template Node
#
# Just serves as a minimal example of a node, should
# not be used. Developers can copy / base additional
# transport types off this template
#
# Copyright (C) 2013 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'rjr/node'

module RJR
module Nodes

class Template < RJR::Node
  RJR_NODE_TYPE = :tpl

  # Template Node Initializer
  def initialize(args = {})
     super(args)
  end

  def to_s
    "RJR::Nodes::Template<>"
  end

  # Send data using specified connection
  #
  # Implementation of RJR::Node#send_msg
  def send_msg(data, connection)
    # TODO
  end

  # Instruct Node to start listening for and dispatching rpc requests
  #
  # Implementation of RJR::Node#listen
  def listen
    # TODO
    self
  end

  # Instructs node to send rpc request, and wait for / return response.
  #
  # Implementation of RJR::Node#invoke
  # @param [String] optional_destination if the transport requires it, param
  #   to specify the target of this request, if not remove this param
  # @param [String] rpc_method json-rpc method to invoke on destination
  # @param [Array] args array of arguments to convert to json and invoke remote method wtih
  def invoke(optional_destination, rpc_method, *args)
    # TODO
  end

  # Instructs node to send rpc notification (immadiately returns / no response is generated)
  #
  # Implementation of RJR::Node#notify
  # @param [String] optional_destination if the transport requires it, param
  #   to specify the target of this request, if not remove this param
  # @param [String] rpc_method json-rpc method to invoke on destination
  # @param [Array] args array of arguments to convert to json and invoke remote method wtih
  def notify(optional_destination, rpc_method, *args)
    # TODO
  end
end # class Template

end # module Nodes
end # module RJR
