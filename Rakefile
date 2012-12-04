require 'rubygems'
require 'bundler'
require 'rubygems/package_task'
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
  t.verbose = true
  t.warning = true
  t.pattern = 'test/*_test.rb'
end

Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_files.include("lib/**/*.rb")
  rdoc.options << "-S"
end

require 'jeweler'

Jeweler::Tasks.new do |gemspec|
  gemspec.name = "workflow"
  gemspec.rubyforge_project = 'workflow'
  gemspec.email = "vladimir@geekq.net"
  gemspec.homepage = "http://www.geekq.net/workflow/"
  gemspec.authors = ["Vladimir Dobriakov"]
  gemspec.summary = "A replacement for acts_as_state_machine."
  gemspec.description = <<-EOS
    Workflow is a finite-state-machine-inspired API for modeling and interacting
    with what we tend to refer to as 'workflow'.

    * nice DSL to describe your states, events and transitions
    * robust integration with ActiveRecord and non relational data stores
    * various hooks for single transitions, entering state etc.
    * convenient access to the workflow specification: list states, possible events
      for particular state
  EOS

  Jeweler::GemcutterTasks.new
end
