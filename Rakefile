# rjr project Rakefile
#
# Copyright (C) 2010-2012 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'rdoc/task'
require "rspec/core/rake_task"

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

desc "build the rjr gem"
task :build do
  system "gem build rjr.gemspec"
end
