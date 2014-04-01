# RJR HasMessages Mixin
#
# Copyright (C) 2014 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

module RJR

# Mixin adding methods allowing developer to define performatted
# messages on a class. After they are defined they may be retrieved,
# manipulated, and sent to the server at any time
module HasMessages
  def self.included(base)
    base.extend(ClassMethods)
  end

  # Wrapper around HasMessages#message
  def define_message(name, &bl)
    self.class.message(name, bl.call)
  end

  module ClassMethods
    # Mechanism to register / retrieve preformatted message
    #
    # @param [Symbol] id id of message to get / set
    # @param [String] msg optional preformatted message to store
    # @return [String] json rpc message
    def message(id, msg=nil)
      @rjr_messages ||= {}
      @rjr_messages[id] = msg unless msg.nil?
      @rjr_messages[id]
    end

    # Clear preformatted messages
    def clear_messages
      @rjr_messages = {}
    end

    # Return random message from registry.
    #
    # Optionally specify the transport which the message must accept.
    # TODO turn this into a generic selection callback
    def rand_message(transport = nil)
      @rjr_messages ||= {}
      messages = @rjr_messages.select { |mid,m| m[:transports].nil? || transport.nil? ||
                                                m[:transports].include?(transport) }
      messages[messages.keys[rand(messages.keys.size)]]
    end
  end
end # module HasMessages
end # module RJR
