require 'rubygems'
require "bundler/gem_tasks"
require 'rake/testtask'
require 'rdoc/task'

task :default => [:test]

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

require 'rake'
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

