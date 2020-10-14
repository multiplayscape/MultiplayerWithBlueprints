
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "awsLambda/version"

Gem::Specification.new do |spec|
  spec.name          = "awsLambda"
  spec.version       = AwsLambda::VERSION
  spec.authors       = ["wukakuki"]
  spec.email         = ["lion547016@gmail.com"]

  spec.summary       = "aws Lambda functions"
  spec.description   = "aws Lambda functions"
  spec.homepage      = "https://www.blockchopstudios.com"
  spec.license       = "MIT"

  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "https://www.blockchopstudios.com/push"

    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = "https://www.blockchopstudios.com/source"
    spec.metadata["changelog_uri"] = "https://www.blockchopstudios.com/changelog"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest"

  spec.add_development_dependency "aws-sdk-kms", '~> 1.24'
  spec.add_development_dependency "aws-sdk-dynamodb", '~> 1.36'
  spec.add_development_dependency "aws-sdk-cognitoidentityprovider", '~> 1.26'
  spec.add_development_dependency "aws-sdk-ses", '~> 1.26'
end
