# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'workflow/version'

Gem::Specification.new do |gem|
  gem.name          = 'workflow'
  gem.version       = Workflow::VERSION
  gem.authors       = ['Vladimir Dobriakov']
  gem.email         = ['vladimir@geekq.net']
  gem.description   = <<END
Workflow is a finite-state-machine-inspired API for modeling and interacting with what we tend to refer to as 'workflow'.
  * nice DSL to describe your states, events and transitions
  * robust integration with ActiveRecord and non relational data stores
  * various hooks for single transitions, entering state etc.
  * convenient access to the workflow specification: list states, possible events for particular state
END
  gem.summary       = 'A replacement for acts_as_state_machine.  '
  gem.homepage      = 'http://www.geekq.net/workflow/'

  gem.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  gem.executables   = gem.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ['lib']

  gem.extra_rdoc_files = [
    'README.markdown'
  ]

  gem.add_development_dependency 'rdoc',    ['>= 3.12']
  gem.add_development_dependency 'bundler', ['>= 1.0.0']
  gem.add_development_dependency 'activerecord'
  gem.add_development_dependency 'sqlite3'
  gem.add_development_dependency 'mocha'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'ruby-graphviz', ['~> 1.0.0']
end
