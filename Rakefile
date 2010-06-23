require 'rubygems'
require 'rake/gempackagetask'
require 'rake/testtask'
require 'rake/rdoctask'

task :default => [:test]

Rake::TestTask.new do |t|
  t.verbose = true
  t.warning = true
  t.pattern = 'test/*_test.rb'
end

Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_files.include("lib/**/*.rb")
  rdoc.options << "-S"
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "workflow"
    gemspec.rubyforge_project = 'workflow'
    gemspec.email = "vladimir@geekq.net"
    gemspec.homepage = "http://blog.geekQ.net/"
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

    Jeweler::RubyforgeTasks.new do |rubyforge|
      rubyforge.doc_task = "rdoc"
    end
  end
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end

