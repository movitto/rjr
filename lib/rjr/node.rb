# RJR Node
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the AGPLv3+ http://www.gnu.org/licenses/agpl.txt

# establish client connection w/ specified args and invoke block w/ 
# newly created client, returning it after block terminates


module RJR

# Defines a node which can be used to dispatch rpc requests and/or register
# handlers for incomping requests.
class Node
  # node always has a node id
  attr_reader :node_id

  def initialize(args = {})
     @node_id = args[:node_id]

     # threads pool to handle incoming requests
     # FIXME make the # of threads and timeout configurable)
     @thread_pool = ThreadPool.new(10, :timeout => 5)
  end


  # instructs node to stop accepting
  def terminate
    @thread_pool.stop
  end
end
end # module RJR
