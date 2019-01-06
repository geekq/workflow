require_relative 'lib/workflow/version'

Gem::Specification.new do |gem|
  gem.name          = "workflow"
  gem.version       = Workflow::VERSION
  gem.authors       = ["Vladimir Dobriakov"]
  gem.email         = ["vladimir@geekq.net"]
  gem.description   = "Workflow is a finite-state-machine-inspired API for modeling and interacting\n    with what we tend to refer to as 'workflow'.\n\n    * nice DSL to describe your states, events and transitions\n    * various hooks for single transitions, entering state etc.\n    * convenient access to the workflow specification: list states, possible events\n      for particular state\n"
  gem.summary       = %q{A replacement for acts_as_state_machine.}
  gem.licenses      = ['MIT']
  gem.homepage      = "http://www.geekq.net/workflow/"

  gem.files         = Dir['CHANGELOG.md', 'README.md', 'LICENSE', 'lib/**/*']
  gem.executables   = gem.files.grep(%r{^bin/}) { |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ['lib']

  gem.extra_rdoc_files = [
    "README.markdown"
  ]

  gem.required_ruby_version = '>= 2.3'
  gem.add_development_dependency 'rdoc',    [">= 3.12"]
  gem.add_development_dependency 'bundler', [">= 1.0.0"]
  gem.add_development_dependency 'mocha'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'minitest'
  gem.add_development_dependency 'ruby-graphviz'

end

