# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'workato/connector/sdk/version'

Gem::Specification.new do |spec|
  spec.name          = 'workato-connector-sdk'
  spec.version       = Workato::Connector::Sdk::VERSION
  spec.authors       = ['Pavel Abolmasov']
  spec.email         = ['pavel.abolmasov@workato.com']
  spec.license       = 'MIT'

  spec.summary       = "Gem for running adapter's code outside Workato infrastructure"
  spec.description   = 'Reproduce key concepts of Workato SDK, DSL, behavior and constraints.'
  spec.homepage      = 'https://www.workato.com/'
  spec.metadata      = {
    'bug_tracker_uri' => 'https://support.workato.com/',
    'documentation_uri' => 'https://docs.workato.com/developing-connectors/sdk/cli.html',
    'homepage_uri' => 'https://www.workato.com/',
    'source_code_uri' => 'https://github.com/workato/workato-connector-sdk'
  }

  spec.files         = Dir['README.md', 'LICENSE.md', 'lib/**/*', 'exe/workato', 'templates/**/*'] +
                       [
                         'templates/.rspec.erb'
                       ]
  spec.bindir        = 'exe'
  spec.executables   = ['workato']
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.4'

  spec.add_development_dependency 'bundler', '~> 1.17'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'stub_server', '~> 0.4'
  spec.add_development_dependency 'timecop', '~> 0.9'
  spec.add_development_dependency 'vcr', '~> 3.0'
  spec.add_development_dependency 'webmock', '~> 3.0'
end
