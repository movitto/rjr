# RJR Ruby Core Extensions
#
# Copyright (C) 2011-2014 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

class String
  # Safely convert string to ruby class it represents
  def to_class
    split(/::/).inject(Object) do |p,c|
      case
      when c.empty?  then p
      when p.constants.collect { |c| c.to_s }.include?(c)
        then p.const_get(c)
      else
        nil
      end
    end
  end
end

if RUBY_VERSION < "1.9"
# We extend object in ruby 1.9 to define 'instance_exec'
#
# {http://blog.jayfields.com/2006/09/ruby-instanceexec-aka-instanceeval.html Further reference}
class Object
  module InstanceExecHelper; end
  include InstanceExecHelper
  # Execute the specified block in the scope of the local object
  # @param [Array] args array of args to be passed to block
  # @param [Callable] block callable object to bind and invoke in the local namespace
  def instance_exec(*args, &block)
    begin
      old_critical, Thread.critical = Thread.critical, true
      n = 0
      n += 1 while respond_to?(mname="__instance_exec#{n}")
      InstanceExecHelper.module_eval{ define_method(mname, &block) }
    ensure
      Thread.critical = old_critical
    end
    begin
      ret = send(mname, *args)
    ensure
      InstanceExecHelper.module_eval{ remove_method(mname) } rescue nil
    end
    ret
  end
end
end

class Class
  class << self
    attr_accessor :whitelist_json_classes
    attr_accessor :permitted_json_classes
  end

  def permit_json_create
    Class.whitelist_json_classes = true
    Class.permitted_json_classes ||= []
    unless Class.permitted_json_classes.include?(self.name)
      Class.permitted_json_classes << self.name
    end
  end
end
