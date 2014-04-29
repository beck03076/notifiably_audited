# encoding: utf-8

Gem::Specification.new do |gem|
  gem.name    = 'notifiably_audited-activerecord'
  gem.version = '0.0.7'

  gem.authors     = ['senthil kumar']
  gem.email       = 'senthilkumar.hce@gmail.com'
  gem.description = 'Log all changes to your ActiveRecord models'
  gem.summary     =  ''
  gem.homepage    = ''
  gem.license     = 'MIT'

  gem.add_dependency 'notifiably_audited', gem.version
  gem.add_dependency 'activerecord', '~> 3.0'

  gem.files         = `git ls-files lib`.split($\).grep(/(active_?record|generators)/)
  gem.files         << 'LICENSE'
  gem.require_paths = ['lib']
end

