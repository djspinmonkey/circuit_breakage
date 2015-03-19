# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'circuit_breakage/version'

Gem::Specification.new do |spec|
  spec.name          = "circuit_breakage"
  spec.version       = CircuitBreakage::VERSION
  spec.authors       = ["John Hyland"]
  spec.email         = ["john@djspinmonkey.com"]
  spec.summary       = %q{Provides a simple circuit breaker pattern.}
  spec.description   = %q{Provides a circuit breaker pattern with optional support for distributed state.}
  spec.homepage      = "https://github.com/djspinmonkey/circuit_breakage"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake", "~> 0"
  spec.add_development_dependency "rspec", "~> 0"
  spec.add_development_dependency "pry", "~> 0"
end
