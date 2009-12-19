# simrpc project Rakefile
#
# Copyright (C) 2009 Mohammed Morsi <movitto@yahoo.com>
# See COPYING for the License of this software

#task :default => :test

task :test do
   desc "Run tests"
   require 'test/simrpc_test'
end

task :rdoc do
  desc "Create RDoc documentation"
  system "rdoc --title 'Simrpc documentation' lib/"
end

task :create_gem do
  desc "Create a new gem"
  system "gem build simrpc.gemspec"
end
