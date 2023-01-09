# frozen_string_literal: true

require_relative "lib/graphql_endpoint/version"

Gem::Specification.new do |spec|
  spec.name = "graphql_endpoint"
  spec.version = GraphqlEndpoint::VERSION
  spec.authors = ["Frank Hall"]
  spec.email = ["ChapterHouse.Dune@gmail.com"]

  spec.summary = "Easily consume graphql from Ruby"
  spec.description = "Consume graphql resources with as little configuration as possible."
  spec.homepage = "http://127.0.0.1/graphql_endpoint"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["allowed_push_host"] = "https://127.0.0.1"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "http://127.0.0.1/graphql_endpoint"
  spec.metadata["changelog_uri"] = "http://127.0.0.1/graphql_endpoint/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency 'bundler', '~> 2.3'
  spec.add_development_dependency 'rake', '~> 13'
  spec.add_development_dependency 'rspec', '~> 3'

  spec.add_dependency 'zeitwerk'
  spec.add_dependency 'graphql-client'
  spec.add_dependency 'activesupport'
end
