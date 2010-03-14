# simrpc project Rakefile
#
# Copyright (C) 2010 Mohammed Morsi <movitto@yahoo.com>
# See LICENSE for the License of this software

require 'rake/rdoctask'
require 'spec/rake/spectask'
require 'rake/gempackagetask'

GEM_NAME="simrpc"
PKG_VERSION=0.2

desc "Run all specs"
Spec::Rake::SpecTask.new('spec') do |t|
  t.spec_files = FileList['spec/*_spec.rb']
end

Rake::RDocTask.new do |rd|
    rd.main = "README.rdoc"
    rd.rdoc_dir = "doc/site/api"
    rd.rdoc_files.include("README.rdoc", "lib/**/*.rb")
end

PKG_FILES = FileList['lib/**/*.rb', 'LICENSE', 'Rakefile', 'README.rdoc', 'spec/**/*.rb' ]

SPEC = Gem::Specification.new do |s|
    s.name = GEM_NAME
    s.version = PKG_VERSION
    s.files = PKG_FILES

    s.required_ruby_version = '>= 1.8.1'
    s.required_rubygems_version = Gem::Requirement.new(">= 1.3.3")
    # FIXME require qpid

    s.author = "Mohammed Morsi"
    s.email = "movitto@yahoo.com"
    s.date = %q{2010-03-11}
    s.description = %q{simrpc is a simple Ruby module for rpc communication, using Apache QPID as the transport mechanism.}
    s.summary     = %q{simrpc is a simple Ruby module for rpc communication, using Apache QPID as the transport mechanism.}
    s.homepage = %q{http://projects.morsi.org/Simrpc}
end

Rake::GemPackageTask.new(SPEC) do |pkg|
    pkg.need_tar = true
    pkg.need_zip = true
end
