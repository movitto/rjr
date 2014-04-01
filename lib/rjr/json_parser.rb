# RJR JSON Parser
#
# Copyright (C) 2014 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'json'
require 'rjr/common'

module RJR

# Provides utilities / helpers to parse json in a sane/safe manner
class JSONParser

  # Extract and return a single json message from a data string.
  #
  # Returns the message and remaining portion of the data string,
  # if message is found, else nil
  #
  # TODO efficiency can probably be optimized in the case closing '}'
  # hasn't arrived yet
  #
  # FIXME if uneven '{' / '}' appears in string data (such as params)
  # this will break, detect when in string and ignore in counts
  def self.extract_json_from(data) 
    return nil if data.nil? || data.empty?
    start  = 0
    start += 1 until start == data.length || data[start].chr == '{'
    on = mi = 0 
    start.upto(data.length - 1).each { |i|
      if data[i].chr == '{'
        on += 1
      elsif data[i].chr == '}'
        on -= 1
      end

      if on == 0
        mi = i
        break
      end
    }
    
    return nil if mi == 0
    return data[start..mi], data[(mi+1)..-1]
  end

  def self.invalid_json_class?(jc)
    Class.whitelist_json_classes ||= false

    Class.whitelist_json_classes ?
      # only permit classes user explicitly authorizes
      !Class.permitted_json_classes.include?(jc) :

      # allow any class
      jc.to_s.split(/::/).inject(Object) do |p,c|
        case
        when c.empty?  then p
        when p.constants.collect { |c| c.to_s }.include?(c)
          then p.const_get(c)
        else
          nil
        end
      end.nil?
  end

  def self.validate_json_hash(jh)
    jh.each { |k,v|
      if k == ::JSON.create_id && invalid_json_class?(v)
        raise ArgumentError, "can't create json class #{v}"
      elsif v.is_a?(Array)
        validate_json_array(v)
      elsif v.is_a?(Hash)
        validate_json_hash(v)
      end
    }
  end

  def self.validate_json_array(ja)
    ja.each { |jai|
      if jai.is_a?(Array)
        validate_json_array(jai)
      elsif jai.is_a?(Hash)
        validate_json_hash(jai)
      end
    }
  end
  
  def self.parse(js)
    jp = ::JSON.parse js, :create_additions => false
    if jp.is_a?(Array)
      validate_json_array(jp)
    elsif jp.is_a?(Hash)
      validate_json_hash(jp)
    else
      return jp
    end
    ::JSON.parse js, :create_additions => true
  end

end # class JSONParser
end # module RJR
