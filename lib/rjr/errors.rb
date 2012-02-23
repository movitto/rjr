# RJR Errors
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the AGPLv3+ http://www.gnu.org/licenses/agpl.txt

# establish client connection w/ specified args and invoke block w/ 
# newly created client, returning it after block terminates

module RJR
module Errors

def self.const_missing(error_name)  # :nodoc:
  if error_name.to_s =~ /Error\z/
    const_set(error_name, Class.new(RuntimeError))
  else
    super
  end
end

end
end
