Gem::Specification.new do |s|
  s.name        = 'nz_covid_pass'
  s.version     = '0.1.1'
  s.licenses    = ['MIT']
  s.summary     = "Reads and validates the signature of NZ Covid Pass passes"
  s.description = "This gem reads in the data contained in a NZ Covid Pass 2D barcode, confirms the signature and outputs the signed data inside"
  s.authors     = ["Roger Nesbitt"]
  s.email       = 'roger@seriousorange.com'
  s.files       = ["lib/nz_covid_pass.rb"]
  s.require_paths = ["lib"]
  s.homepage    = 'https://github.com/mogest/nz_covid_pass'

  s.add_runtime_dependency 'base32', '~> 0.3.4'
  s.add_runtime_dependency 'cose', '~> 1.2.0'
  s.add_runtime_dependency 'cbor', '~> 0.5.9.6'
  s.add_runtime_dependency 'cwt', '~> 0.5.0'
  s.add_runtime_dependency 'jwt', '~> 2.3.0'

  s.add_development_dependency 'test-unit', '~> 3.5.1'
end
