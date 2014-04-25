# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'guacamole/version'

Gem::Specification.new do |spec|
  spec.name          = 'guacamole'
  spec.version       = Guacamole::VERSION
  spec.authors       = ['Lucas Dohmen', 'Dirk Breuer']
  spec.email         = ['moonglum@moonbeamlabs.com', 'dirk.breuer@gmail.com']
  spec.description   = %q{ODM for ArangoDB}
  spec.summary       = %q{An ODM for ArangoDB that uses the DataMapper pattern.}
  spec.homepage      = 'https://github.com/triAGENS/guacamole'
  spec.license       = 'Apache License 2.0'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(spec)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'ashikawa-core', '~> 0.10.0'
  spec.add_dependency 'virtus', '~> 1.0.1'
  spec.add_dependency 'activesupport', '>= 4.0.0'
  spec.add_dependency 'activemodel', '>= 4.0.0'
  spec.add_dependency 'hamster', '~> 1.0.1.pre.rc.1'

  spec.add_development_dependency 'fabrication', '~> 2.8.1'
  spec.add_development_dependency 'faker', '~> 1.2.0'
  spec.add_development_dependency 'logging', '~> 1.8.1'
  spec.add_development_dependency 'pry', '~> 0.9.12'
end
