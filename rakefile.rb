require 'rubygems'
require 'rake/gempackagetask'
require 'rake/testtask'
require 'rake/rdoctask'

task :default => [:test]

Rake::TestTask.new do |t|
  t.verbose = true
  t.warning = true
end

PKG_VERSION = "1.0.0"
PKG_FILES = FileList[
  'LICENSE',
  'Rakefile',
  'lib/**/*.rb',
  'test/**/test_*.rb'
]

spec = Gem::Specification.new do |s|
  s.name = "geekQ-workflow"
  s.version = PKG_VERSION
  s.author = "Vladimir Dobriakov"
  s.email = "vladimir@geekq.net"
  s.homepage = "http://www.geekQ.net/"
  s.platform = Gem::Platform::RUBY
  s.summary = "A replacement for acts_as_state_machine."
  s.files = PKG_FILES.to_a
  s.require_path = "lib"
end

Rake::RDocTask.new do |rdoc|
  rdoc.main = "README"
  rdoc.rdoc_files.include("README", "lib/**/*.rb")
  rdoc.options << "-S"
end

package_task = Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_zip = true
  pkg.need_tar_gz = true
end
