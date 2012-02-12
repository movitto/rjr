# RJR Utility Methods
#
# Copyright (C) 2011 Mohammed Morsi <mo@morsi.org>
# Licensed under the AGPLv3+ http://www.gnu.org/licenses/agpl.txt

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
