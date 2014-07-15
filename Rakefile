require 'rubygems'
require 'bundler'
Bundler.setup

require 'rake'
require 'rake/testtask'
require 'rdoc/task'
require 'wwtd/tasks'

desc 'Default: run all tests via Travis-CI simulation (wwtd:local).'
task :default => 'wwtd:local'

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.verbose = true
  t.warning = true
  t.test_files = FileList['test/*_test.rb'] + FileList['test/new_versions/*_test.rb']
end

Rake::TestTask.new do |t|
  t.name = 'test_without_new_versions'
  t.libs << 'test'
  t.verbose = true
  t.warning = true
  t.pattern = 'test/*_test.rb'
end

Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_files.include("lib/**/*.rb")
  rdoc.options << "-S"
end

