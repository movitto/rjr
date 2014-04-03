# RJR Logger Class
#
# Copyright (C) 2011-2014 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'logger'

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
         @filters = []
         @highlights = []
       end
    end

  public

    # Add method which to call on every log message to determine
    # if messages should be included/excluded
    def self.add_filter(filter)
      @logger_mutex.synchronize{
        @filters << filter
      }
    end

    # Add a method which to call on every log message to determine
    # if message should be highlighted
    def self.highlight(hlight)
      @logger_mutex.synchronize{
        @highlights << hlight
      }
    end

    def self.method_missing(method_id, *args)
       _instantiate_logger
       @logger_mutex.synchronize {
         args = args.first if args.first.is_a?(Array)
         args.each { |a|
           # run highlights / filters against output before
           # sending formatted output to logger
           # TODO allow user to customize highlight mechanism/text
           na = @highlights.any? { |h| h.call a } ?
                  "\e[1m\e[31m#{a}\e[0m\e[0m" : a
           @logger.send(method_id, na) if @filters.all? { |f| f.call a }
         }
       }
    end

    def self.safe_exec(*args, &bl)
      _instantiate_logger
      @logger_mutex.synchronize {
        bl.call *args
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

# Serialized puts, uses logger lock to serialize puts output.
# Definiting it in Kernel as 'puts' is defined there
#
# Though this could go in core_ext, since it's pretty specific
# to RJR logger, adding here
module Kernel
  def sputs(*args)
    ::RJR::Logger.safe_exec {
      puts *args
    }
  end
end
