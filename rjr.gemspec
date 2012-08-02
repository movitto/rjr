# -*- encoding: utf-8 -*-

GEM_NAME    = 'rjr'
PKG_VERSION = '0.6.1'

PKG_FILES =
  Dir.glob('{lib,specs}/**/*.rb') + ['LICENSE', 'Rakefile', 'README.rdoc']


Gem::Specification.new do |s|
    s.name    = GEM_NAME
    s.version = PKG_VERSION
    s.files   = PKG_FILES
    s.executables << 'rjr-server'

    s.required_ruby_version = '>= 1.8.1'
    s.required_rubygems_version = Gem::Requirement.new(">= 1.3.3")
    s.add_development_dependency('rspec', '~> 1.3.0')

    s.author = "Mohammed Morsi"
    s.email = "mo@morsi.org"
    s.date = %q{2012-08-02}
    s.description = %q{Ruby Json Rpc library}
    s.summary = %q{JSON RPC server and client library over amqp, websockets, http, etc}
    s.homepage = %q{http://github.com/movitto/rjr}
end
