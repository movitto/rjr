# RJR MultiNode Endpoint
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the AGPLv3+ http://www.gnu.org/licenses/agpl.txt

# establish client connection w/ specified args and invoke block w/ 
# newly created client, returning it after block terminates

require 'eventmachine'
require 'rjr/node'
require 'rjr/message'

module RJR

class MultiNode < RJR::Node
  # initialize the node w/ the specified params
  def initialize(args = {})
    super(args)
    @nodes = args[:nodes]
  end


  # Instruct Node to start listening for and dispatching rpc requests
  def listen
    @nodes.each { |node|
      node.listen
    }
  end
end

end
