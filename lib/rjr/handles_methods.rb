# RJR HandlesMethods Mixin
#
# Copyright (C) 2014 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

module RJR

# Mixin adding methods allowing developer to specify JSON-RPC
# methods which to dispatch to.
module HandlesMethods
  def self.included(base)
    base.extend(ClassMethods)
  end

  # Override w/ custom handler logic
  #
  # XXX handler method needs to be defined before jr_method is called,
  # not a problem for default case, but could be a pain in custom case
  def handle
  end

  module ClassMethods
    attr_accessor :jr_methods

    # Return the handler method matching the argument set
    def extract_handler_method(args)
      handler = nil

      if method_defined?(args.last)
        handler = args.last
        args.delete_at(-1)

      else
        handler = :handle
      end

      [handler, args]
    end

    # Return bool indicating if handler exists for the specified method
    def has_handler_for?(handler_method)
      @jr_handlers ||= {}
      @jr_handlers.has_key?(handler_method)
    end

    # Returns handler for specified method
    def handler_for(handler_method)
      @jr_handlers[handler_method]
    end

    # Create handler for specified method.
    #
    # Creates a proc that gets evaluated via instance_exec in request
    def create_handler_for(handler_method)
      @jr_handlers ||= {}
      handler_class = self

      @jr_handlers[handler_method] = proc { |*args|
        # instantiate new handler instance
        jr_instance = handler_class.new

        # setup scope to include request variables
        instance_variables.each { |iv|
          jr_instance.instance_variable_set(iv, instance_variable_get(iv))
        }

        # invoke handler method
        jr_instance.method(handler_method).call *args
      }
    end

    # Register one or more json-rpc methods.
    #
    # Invoke w/ list of method signatures to match in dispatcher
    # w/ optional id of local method to dispatch to. If no method
    # specified, the :handle method will be used
    def jr_method(*args)
      @jr_methods  ||= []

      handler_method, args = extract_handler_method(args)

      handler = has_handler_for?(handler_method) ?
        handler_for(handler_method) : create_handler_for(handler_method)

      @jr_methods << [args, handler]
    end

    # Register locally stored methods w/ the specified dispatcher
    def dispatch_to(dispatcher)
      jr_methods.each { |handlers, method|
        dispatcher.handle handlers, method
      }
    end
  end # module ClassMethods
end # module HandlesMethods 
end # module RJR
