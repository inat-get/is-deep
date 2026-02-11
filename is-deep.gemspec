# frozen_string_literal: true

require_relative 'lib/is-deep/info'

Gem::Specification::new do |spec|
  spec.name     =   IS::Deep::Info::NAME
  spec.version  =   IS::Deep::Info::VERSION
  spec.summary  =   IS::Deep::Info::SUMMARY
  spec.license  =   IS::Deep::Info::LICENSE
  spec.authors  = [ IS::Deep::Info::AUTHOR ]
  spec.homepage =   IS::Deep::Info::HOMEPAGE

  spec.files = Dir[ 'lib/**/*', 'README.md', 'LICENSE' ]

  spec.required_ruby_version = '>= 3.4'

  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'yard'
  spec.add_development_dependency 'redcarpet'
  spec.add_development_dependency 'rdoc'
end
