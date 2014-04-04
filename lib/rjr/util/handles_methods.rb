# RJR HandlesMethods Mixin
#
# Copyright (C) 2014 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

module RJR

# Mixin adding methods allowing developer to specify JSON-RPC
# methods which to dispatch to.
#
# @example Defining a structured JSON-RPC method handler
#   class MyMethodHandler
#     include RJR::HandlesMethods
#
#     jr_method :do_something
#
#     def handle(*params)
#       'return value'
#     end
#   end
#
#   node = RJR::Nodes::TCP.new :host => '0.0.0.0', :port => 8888
#   MyMethodHandler.dispatch_to(node.dispatcher)
#   node.listen.join
#
#   # clients can now invoke the 'do_something' json-rpc method by
#   # issuing requests to the target host / port
#
module HandlesMethods
  def self.included(base)
    base.extend(ClassMethods)
  end

  # Override w/ custom handler logic
  def handle
  end

  module ClassMethods
    attr_accessor :jr_handlers

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
      @jr_method_args  ||= []
      @jr_method_args  << args
    end

    # Register locally stored methods w/ the specified dispatcher
    def dispatch_to(dispatcher)
      @jr_method_args.each { |args|
        # copy args so original is preserved
        handler_method, jr_methods =
          extract_handler_method(Array.new(args))
        jr_methods.map! { |m| m.to_s }

        handler = has_handler_for?(handler_method) ?
                       handler_for(handler_method) :
                create_handler_for(handler_method)

        dispatcher.handle jr_methods, handler
      }
    end
  end # module ClassMethods
end # module HandlesMethods 
end # module RJR
