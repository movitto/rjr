# Low level RJR Utility Methods
#
# Assortment of helper methods and methods that don't fit elsewhere
#
# Copyright (C) 2011-2013 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'json'

# Return a random uuid
def gen_uuid
  ["%02x"*4, "%02x"*2, "%02x"*2, "%02x"*2, "%02x"*6].join("-") %
      Array.new(16) {|x| rand(0xff) }
end

module RJR

# Return the persistent rjr nodes
def self.persistent_nodes
  # rerun each time (eg don't store in var) incase new nodes were included
  RJR::Nodes.constants.collect { |n|
    nc = RJR::Nodes.const_get(n)
    nc.superclass == RJR::Node && nc.persistent? ?
    nc : nil
  }.compact
end

end
