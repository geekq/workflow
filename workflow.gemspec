# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "railsware-workflow"
  s.version     = "0.8.1"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Vladimir Dobriakov"]
  s.email       = ["vladimir@geekq.net"]
  s.homepage    = "https://github.com/railsware/workflow"
  s.summary     = "A replacement for acts_as_state_machine."
  s.description = <<-EOS
  Workflow is a finite-state-machine-inspired API for modeling and interacting
  with what we tend to refer to as 'workflow'.

  * nice DSL to describe your states, events and transitions
  * robust integration with ActiveRecord and non relational data stores
  * various hooks for single transitions, entering state etc.
  * convenient access to the workflow specification: list states, possible events
    for particular state
  EOS

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
