require_relative 'lib/background_job/version'

Gem::Specification.new do |spec|
  spec.name          = 'background_job'
  spec.version       = BackgroundJob::VERSION
  spec.authors       = ['Marcos G. Zimmermann']
  spec.email         = ['mgzmaster@gmail.com']

  spec.summary       = <<~SUMMARY
    A generic swappable background job client.
  SUMMARY
  spec.description   = <<~DESCRIPTION
    A generic swappable background job client that allows you to push jobs to different background job services.
  DESCRIPTION

  spec.homepage      = 'https://github.com/marcosgz/background_job'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.7.0')

  raise 'RubyGems 2.0 or newer is required to protect against public gem pushes.' unless spec.respond_to?(:metadata)
  spec.metadata['homepage_uri']      = spec.homepage
  spec.metadata['bug_tracker_uri']   = 'https://github.com/marcosgz/background_job/issues'
  spec.metadata['documentation_uri'] = 'https://github.com/marcosgz/background_job'
  spec.metadata['source_code_uri']   = 'https://github.com/marcosgz/background_job'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end

  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'redis', '>= 0.0.0'
  spec.add_dependency 'multi_json', '>= 0.0.0'
end
