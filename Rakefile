require "bundler/gem_tasks"
require "rake/testtask"
require 'rdoc/task'

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.verbose = true
  t.warning = true
  t.test_files = FileList["test/**/*_test.rb"]
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

task :default => :test
