# rjr - Ruby Json Rpc
#
# Copyright (C) 2010-2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

# rjr - Ruby Json Rpc
module RJR ; end

#require 'rubygems'
require 'rjr/common'
require 'rjr/errors'
require 'rjr/thread_pool'
require 'rjr/thread_pool2'
require 'rjr/em_adapter'
require 'rjr/semaphore'
require 'rjr/node'
require 'rjr/dispatcher'
require 'rjr/message'
require 'rjr/local_node'
require 'rjr/ws_node'
require 'rjr/tcp_node'
require 'rjr/multi_node'

begin
  require 'amqp'
  require 'rjr/amqp_node'
rescue LoadError
  require 'rjr/missing_node'
  RJR::AMQPNode = RJR::MissingNode
  # TODO output: "amqp gem could not be loaded, skipping amqp node definition"
end

begin
  require 'evma_httpserver'
  require 'em-http-request'
  require 'rjr/web_node'

# TODO rather that fail, use alternative deps
rescue LoadError
  require 'rjr/missing_node'
  RJR::WebNode = RJR::MissingNode
  # TODO output: "curb/evma_httpserver gems could not be loaded, skipping web node definition"
end

require 'rjr/util'
