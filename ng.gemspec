# -*- encoding: utf-8 -*-
require File.expand_path('../lib/nailgun/client/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ['Ryan Taylor Long']
  gem.email         = ['ryan@rtlong.com']
  gem.description   = %q{Pure-Ruby Nailgun client port}
  gem.summary       = %q{Eliminates the need to shell-out when using Nailgun}
  gem.homepage      = ''

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = 'ng'
  gem.require_paths = ['lib']
  gem.version       = Nailgun::Client::VERSION
end
