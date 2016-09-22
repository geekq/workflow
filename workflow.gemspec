# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'workflow/version'
Gem::Specification.new do |spec|
  spec.name          = "rails-workflow"
  spec.version       = Workflow::VERSION
  spec.authors       = ["Tyler Gannon"]
  spec.email         = ["tyler@aprilseven.co"]

  spec.summary       = %q{A finite-state-machine-inspired API for managing state changes in ActiveModel objects.  Based on Vladimir Dobriakov's Workflow gem (https://github.com/geekq/workflow)}
  spec.description   = %q{Workflow specifically for ActiveModel objects.}
  spec.homepage      = "https://github.com/tylergannon/rails-workflow"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features|doc)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.extra_rdoc_files = [
    "README.markdown"
  ]

  spec.add_dependency 'activerecord'
  spec.add_dependency 'activesupport'

  spec.add_development_dependency 'rdoc',    [">= 3.12"]
  spec.add_development_dependency 'sqlite3'
  spec.add_development_dependency 'mocha'
  spec.add_development_dependency 'yard'
  spec.add_development_dependency 'cancancan'
  spec.add_development_dependency 'redcarpet'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'test-unit'
  spec.add_development_dependency 'ruby-graphviz', ['~> 1.0.0']
  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.required_ruby_version = '>= 2.3'

end
