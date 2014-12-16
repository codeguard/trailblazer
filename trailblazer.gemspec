# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'trailblazer/version'

Gem::Specification.new do |spec|
  spec.name          = "trailblazer"
  spec.version       = Trailblazer::VERSION
  spec.authors       = ["Steve Eley"]
  spec.email         = ["sfeley@gmail.com"]
  spec.summary       = %q{Update Amazon route tables to bypass NAT for AWS services}
  spec.description   = %q{A route table maintenance utility for VPC subnets that want *most* Internet traffic behind a NAT, but want direct access to Amazon AWS services. Given a route table as the single required parameter, it downloads the latest [IP Ranges JSON file](https://ip-ranges.amazon.com/ip-ranges.json) and directs any CIDR blocks in the VPC's region to the VPC's internet gatweay. Other routes of importance may be registered via command line options or a configuration YAML file.
}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "aws-sdk", "~> 1.59"
  spec.add_runtime_dependency "logging", "~> 1.8"
  spec.add_runtime_dependency "trollop", "~> 2.0"

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
end
