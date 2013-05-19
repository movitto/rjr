# Low level RJR Utility Methods
#
# Assortment of helper methods and methods that don't fit elsewhere
#
# Copyright (C) 2011-2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'logger'

# Return a random id
def gen_uuid
  ["%02x"*4, "%02x"*2, "%02x"*2, "%02x"*2, "%02x"*6].join("-") %
      Array.new(16) {|x| rand(0xff) }
end

module RJR

# Logger helper class.
#
# Encapsulates the standard ruby logger in a thread safe manner. Dispatches
# class methods to an internally tracked logger to provide global access.
#
# TODO handle logging errors (log size too big, logrotate, etc)
#
# @example
#   RJR::Logger.info 'my message'
#   RJR::Logger.warn 'my warning'
class Logger
  private
    def self._instantiate_logger
       if @logger.nil?
         #STDOUT.sync = true
         output = @log_to || ENV['RJR_LOG'] || STDOUT
         @logger = ::Logger.new(output)
         @logger.level = @log_level || ::Logger::FATAL
         @logger_mutex = Mutex.new
       end 
    end 

  public

    def self.method_missing(method_id, *args)
       _instantiate_logger
       @logger_mutex.synchronize {
         if args.first.is_a?(Array)
           args.first.each{ |a|
             @logger.send(method_id, a)
           }
         else
           @logger.send(method_id, args)
         end
       }
    end 

    def self.logger
       _instantiate_logger
       @logger
    end

    # Set log destination
    # @param dst destination which to log to (file name, STDOUT, etc)
    def self.log_to(dst)
      @log_to = dst
      @logger = nil
      _instantiate_logger
    end

    # Set log level.
    # @param level one of the standard rails log levels (default fatal)
    def self.log_level=(level)
      _instantiate_logger
      if level.is_a?(String)
        level = case level
                when 'debug' then
                  ::Logger::DEBUG
                when 'info' then
                  ::Logger::INFO
                when 'warn' then
                  ::Logger::WARN
                when 'error' then
                  ::Logger::ERROR
                when 'fatal' then
                  ::Logger::FATAL
                end
      end
      @log_level    = level
      @logger.level = level
    end

    # Return true if log level is set to debug, else false
    def self.debug?
      @log_level == ::Logger::DEBUG
    end
end

end # module RJR

class Object
  def eigenclass
    class << self
      self
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
