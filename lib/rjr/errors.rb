# RJR Errors
#
# Copyright (C) 2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

module RJR

# The RJR::Errors module provides a mechanism to dynamically create errors
# on demand as they are needed. At some point this will go away / be replaced
# with a more rigidly / fixed defined error heirarchy.
module Errors

# Catches all Errors constants and define new RuntimeError subclass
def self.const_missing(error_name)  # :nodoc:
  if error_name.to_s =~ /Error\z/
    const_set(error_name, Class.new(RuntimeError))
  else
    super
  end
end

end
end
