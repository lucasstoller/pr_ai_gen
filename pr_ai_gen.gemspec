Gem::Specification.new do |spec|
  spec.name          = "pr_ai_gen"
  spec.version       = "0.1.0"
  spec.authors       = ["Lucas Stoller"]
  spec.email         = ["l.s.stoller@gmail.com"]
  spec.summary       = "A CLI tool to generate pull requests using OpenAI"
  spec.description   = "This tool automates the process of creating pull requests by using OpenAI to generate the content based on the differences between two git branches."
  spec.homepage      = "https://theright.dev"

  spec.files         = `git ls-files`.split($/)
  spec.bindir        = "exe"
  spec.executables   = spec.executables = ['pr-ai-gen']
  spec.require_paths = ["lib"]

  spec.add_dependency "git"
  spec.add_dependency "openai"
  spec.add_dependency "octokit"
  spec.add_dependency "capybara"
  spec.add_dependency "selenium-webdriver"

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
end