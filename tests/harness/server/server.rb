require 'rjr/util'
include RJR::Definitions

rjr_method \
  :messages =>
    lambda {
        $messages.string.split("\n")
    },

  :failed =>
    lambda { |p|
      RJR::Logger.info "invoked failed method #{p}"
     raise ArgumentError, "err #{p}"
    },

  :stress =>
    lambda { |p|
      RJR::Logger.info "invoked stress method #{p}"
     "foobar #{p}"
    },

  :stress_callback =>
    lambda { |p|
      RJR::Logger.info "invoked stress_callback method #{p}"
      @rjr_callback.invoke 'client_callback', p
      "barfoo #{p}"
    } 
