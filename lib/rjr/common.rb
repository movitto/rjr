# RJR Utility Methods
#
# Copyright (C) 2011 Mohammed Morsi <mo@morsi.org>
# Licensed under the AGPLv3+ http://www.gnu.org/licenses/agpl.txt

require 'logger'

module RJR

# Logger helper class
class Logger
  private
    def self._instantiate_logger
       unless defined? @@logger
         @@logger = ::Logger.new(STDOUT)
         @@logger.level = ::Logger::FATAL
       end 
    end 

  public

    def self.method_missing(method_id, *args)
       _instantiate_logger
       @@logger.send(method_id, args)
    end 

    def self.logger
       _instantiate_logger
       @@logger
    end

    def self.log_level=(level)
      _instantiate_logger
      @@logger.level = level
    end
end

end # module RJR

# http://blog.jayfields.com/2006/09/ruby-instanceexec-aka-instanceeval.html
class Object
  module InstanceExecHelper; end
  include InstanceExecHelper
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
