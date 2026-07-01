# frozen_string_literal: true

require_relative "lib/call_map/version"

Gem::Specification.new do |spec|
  spec.name = "call_map"
  spec.version = CallMap::VERSION
  spec.authors = ["bumpfuji10"]
  spec.email = ["bumpfuji10@gmail.com"]

  spec.summary = "Generate readable call maps from Rails controller actions."
  spec.description = "CallMap helps Rails developers follow application call paths from controller actions."
  spec.homepage = "https://github.com/bumpfuji10/call_map"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Prism is a default gem since Ruby 3.3.0, but not bundled on 3.2, so declare it explicitly.
  spec.add_dependency "prism", ">= 1.0"
end
