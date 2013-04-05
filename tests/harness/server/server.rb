require 'rjr/util'
include RJR::Definitions

rjr_method \
  :messages =>
    lambda {
        $messages.string.split("\n")
    },

  :stress =>
    lambda { |p|
      RJR::Logger.info "invoked stress method #{p}"
     'foobar'
    },

  :stress_callback =>
    lambda { |p|
      RJR::Logger.info "invoked stress_callback method #{p}"
      @rjr_callback.invoke 'client_callback', p
      'barfoo'
    } 
