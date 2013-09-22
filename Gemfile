source 'https://rubygems.org'

gemspec :name => 'rjr'

# see issue w/ json gem:
# https://github.com/flori/json/issues/179
gem 'json', '= 1.7.5'

# this is primarily for travis so
# include all optional deps
gem 'eventmachine_httpserver'
gem 'em-http-request'
gem 'em-websocket'
gem 'em-websocket-client'
#gem 'amqp'

group :test do
  gem 'rake'
  gem 'rspec'
end
