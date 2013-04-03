module RJR::Messages
  @rjr_stress = { :method => 'stress',
                  :params => ["<CLIENT_ID>"],
                  :result => lambda { |r| r == 'foobar' } }

  @rjr_stress_callback = { :method => 'stress_callback',
                  :params => ["<CLIENT_ID>"],
                  :result => lambda { |r| r == 'barfoo' } }
end
