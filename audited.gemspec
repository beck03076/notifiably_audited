# encoding: utf-8

Gem::Specification.new do |gem|
  gem.name    = 'notifiably_audited'
  gem.version = '0.0.7'

  gem.authors     = ['senthil kumar']
  gem.email       = 'senthilkumar.hce@gmail.com'
  gem.description = 'Log all changes to your ActiveRecord models'
  gem.summary     =  ''
  gem.homepage    = ''
  gem.license     = 'MIT'

  gem.add_development_dependency 'activerecord', '~> 3.0'
  gem.add_development_dependency 'appraisal', '~> 0.4'
  gem.add_development_dependency 'bson_ext', '~> 1.6'
  gem.add_development_dependency 'mongo_mapper', '~> 0.11'
  gem.add_development_dependency 'rails', '~> 3.0'
  gem.add_development_dependency 'rspec-rails', '~> 2.0'
  gem.add_development_dependency 'sqlite3', '~> 1.0'
  
  gem.add_dependency 'private_pub'

  gem.files         = `git ls-files`.split($\).reject{|f| f =~ /(lib\/audited\-|adapters|generators)/ }
  gem.test_files    = gem.files.grep(/^spec\//)
  gem.require_paths = ['lib']
end

