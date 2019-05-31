require "bundler/gem_tasks"
require "rake/testtask"
require 'rdoc/task'

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.verbose = true
  t.warning = true
  t.test_files = FileList["test/**/*_test.rb"]

  # Require and start simplecov BEFORE minitest/autorun loads ./lib to get correct test results.
  # Otherwise lot of executed lines are not detect.
  require 'simplecov'
  SimpleCov.start do
    add_filter 'test'
  end
end

Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_files.include("lib/**/*.rb")
  rdoc.options << "-S"
end

task :default => :test
