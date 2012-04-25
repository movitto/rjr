# rjr project Rakefile
#
# Copyright (C) 2010 Mohammed Morsi <movitto@yahoo.com>
# Licensed under the AGPLv3+ http://www.gnu.org/licenses/agpl.txt

require 'rdoc/task'
require "rspec/core/rake_task"
require 'rubygems/package_task'


GEM_NAME="rjr"
PKG_VERSION='0.5.4'

desc "Run all specs"
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = 'specs/**/*_spec.rb'
  spec.rspec_opts = ['--backtrace']
end

desc "run javascript tests"
task :test_js do
  ENV['RUBYLIB'] = "lib"
  puts "Launching js test runner"
  system("tests/js/runner")
end

desc "run integration/stress tests"
task :integration do
  ENV['RUBYLIB'] = "lib"
  puts "Launching integration test runner"
  system("tests/integration/runner")
end

Rake::RDocTask.new do |rd|
    rd.main = "README.rdoc"
    rd.rdoc_dir = "doc/site/api"
    rd.rdoc_files.include("README.rdoc", "lib/**/*.rb")
end

PKG_FILES = FileList['lib/**/*.rb', 
  'LICENSE', 'Rakefile', 'README.rdoc', 'spec/**/*.rb' ]

SPEC = Gem::Specification.new do |s|
    s.name = GEM_NAME
    s.version = PKG_VERSION
    s.files = PKG_FILES
    s.executables << 'rjr-server'

    s.required_ruby_version = '>= 1.8.1'
    s.required_rubygems_version = Gem::Requirement.new(">= 1.3.3")
    s.add_development_dependency('rspec', '~> 1.3.0')

    s.author = "Mohammed Morsi"
    s.email = "mo@morsi.org"
    s.date = %q{2012-04-25}
    s.description = %q{Ruby Json Rpc library}
    s.summary = %q{JSON RPC server and client library over amqp, websockets}
    s.homepage = %q{http://github.com/movitto/rjr}
end

Gem::PackageTask.new(SPEC) do |pkg|
    pkg.need_tar = true
    pkg.need_zip = true
end
