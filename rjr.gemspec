# -*- encoding: utf-8 -*-

GEM_NAME    = 'rjr'
PKG_VERSION = '0.16.3'

PKG_FILES =
  Dir.glob('{examples,lib,site,specs}/**/*.rb') +
  Dir.glob('site/*.{html,js}') +
  ['LICENSE', 'Rakefile', 'README.md']

Gem::Specification.new do |s|
    s.name    = GEM_NAME
    s.version = PKG_VERSION
    s.files   = PKG_FILES
    s.executables   = ['rjr-server', 'rjr-client', 'rjr-client-launcher']
    s.require_paths = ['lib']

    s.required_ruby_version = '>= 1.8.1'
    s.required_rubygems_version = Gem::Requirement.new(">= 1.3.3")
    s.add_development_dependency('rspec', '>= 2.0.0')
    s.add_dependency('eventmachine')
    s.add_dependency('json', '<= 1.7.5')

    s.requirements = ['The amqp gem and a running rabbitmq server is needed to use the amqp node',
                      'The eventmachine_httpserver and em-http-request gems are needed to use the web node',
                      'The em-websocket and em-websocket-client gems are needed to use the web socket node']

    s.author = "Mohammed Morsi"
    s.email = "mo@morsi.org"
    s.date = %q{2013-09-26}
    s.description = %q{Ruby Json Rpc library}
    s.summary = %q{JSON RPC server and client library over amqp, websockets, http, etc}
    s.homepage = %q{http://github.com/movitto/rjr}
    s.licenses = ["Apache 2.0"]
end
