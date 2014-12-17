# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'guacamole/version'

Gem::Specification.new do |spec|
  spec.name          = 'guacamole'
  spec.version       = Guacamole::VERSION
  spec.authors       = ['Lucas Dohmen', 'Dirk Breuer']
  spec.email         = ['lucas@arangodb.com', 'dirk@arangodb.com']
  spec.description   = %q{ODM for ArangoDB}
  spec.summary       = %q{An ODM for ArangoDB that uses the DataMapper pattern.}
  spec.homepage      = 'http://guacamolegem.org'
  spec.license       = 'Apache License 2.0'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(spec)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'ashikawa-core', '~> 0.12.0'
  spec.add_dependency 'virtus', '~> 1.0.1'
  spec.add_dependency 'activesupport', '>= 4.0.0'
  spec.add_dependency 'activemodel', '>= 4.0.0'
  spec.add_dependency 'hamster', '~> 1.0.1.pre.rc.1'

  spec.add_development_dependency 'bcrypt', '3.1.7'
  spec.add_development_dependency 'codeclimate-test-reporter', '~> 0.3.0'
  spec.add_development_dependency 'fabrication', '~> 2.8.1'
  spec.add_development_dependency 'faker', '~> 1.2.0'
  spec.add_development_dependency 'guard', '~> 2.6.1'
  spec.add_development_dependency 'guard-bundler', '~> 2.0.0'
  spec.add_development_dependency 'guard-rspec', '~> 4.2.10'
  spec.add_development_dependency 'inch', '~> 0.4.6'
  spec.add_development_dependency 'logging', '~> 1.8.1'
  spec.add_development_dependency 'pry', '~> 0.9.12'
  spec.add_development_dependency 'rake', '~> 10.3.2'
  spec.add_development_dependency 'reek', '~> 1.3.8'
  spec.add_development_dependency 'rspec', '~> 3.0.0'
  spec.add_development_dependency 'timecop', '~> 0.7.1'
  spec.add_development_dependency 'yard', '~> 0.8.7.4'
end
