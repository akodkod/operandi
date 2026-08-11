# frozen_string_literal: true

require_relative "lib/operandi/version"

Gem::Specification.new do |spec|
  spec.name          = "operandi"
  spec.version       = Operandi::VERSION
  spec.authors       = ["Andrew Kodkod"]
  spec.email         = ["andrew@kodkod.me"]

  spec.summary       = "Robust service architecture for Ruby/Rails applications"
  spec.description   = "Operandi is a simple yet powerful way to organize business logic in Ruby applications. Build services that are easy to test, maintain, and understand." # rubocop:disable Layout/LineLength
  spec.homepage      = "https://operandi.kodkod.me/"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 3.2.0")

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/akodkod/operandi"
  spec.metadata["changelog_uri"] = "https://github.com/akodkod/operandi/blob/main/CHANGELOG.md"

  # Package only runtime code and user-facing support files.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir[
      "CHANGELOG.md",
      "LICENSE.txt",
      "README.md",
      "config/default.yml",
      "lib/**/*",
      "rbi/**/*",
    ].select { |file| File.file?(file) }.sort
  end

  spec.bindir                            = "exe"
  spec.executables                       = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths                     = ["lib"]
  spec.metadata["rubygems_mfa_required"] = "true"
end
