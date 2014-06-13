# RJR Request Message
#
# Copyright (C) 2012-2014 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'json'
require 'rjr/util/json_parser'

module RJR
module Messages

# Intermediate representation of a JSON-RPC data containing
# extracted/parsed data which has not been analysed.
class Intermediate
  # JSON from which data is extracted from
  attr_accessor :json

  # Data extracted from message
  attr_accessor :data

  def initialize(args = {})
    @json = args[:json] || nil
    @data = args[:data] ||  {}
  end

  def keys
    data.keys
  end

  def [](key)
    data[key.to_s]
  end

  def has?(key)
    data.key?(key)
  end

  def self.parse(json)
    parsed = nil

    #allow parsing errs to propagate up
    parsed = JSONParser.parse(json)

    self.new :json => json,
             :data => parsed
  end

end # class Intermediate
end # module Messages
end # module RJR
