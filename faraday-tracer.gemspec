# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = 'faraday-tracer'
  spec.version       = '0.5.0'
  spec.authors       = ['SaleMove TechMovers']
  spec.email         = ['techmovers@salemove.com']

  spec.summary       = %q{Faraday OpenTracing middleware}
  spec.description   = %q{}
  spec.homepage      = 'https://github.com/salemove/faraday-tracer'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.require_paths = ['lib']

  spec.add_dependency 'opentracing'

  spec.add_development_dependency "test-tracer", "~> 1.0"
  spec.add_development_dependency "tracing-matchers", "~> 1.0"
  spec.add_development_dependency 'bundler', '~> 1.14'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'faraday'
end
