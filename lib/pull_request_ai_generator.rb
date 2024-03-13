require 'optparse'
require 'git'
require 'httparty'
require 'octokit'
require 'capybara/dsl'
require 'pry'

# Define the CLI class
class PullRequestAIGenerator
  OPEN_AI_URL = "https://api.openai.com/v1"

  include Capybara::DSL

  attr_reader :options

  def initialize(args)
    @options = parse_options(args)
    @diff = nil
    @pr_content = nil
    @git_repo = nil
  end

  def init
    puts 'Initializing pr-ai-gen...'
    credentials_path = File.expand_path('~/.pr-gem/credentials')
    pr_gem_path = File.expand_path('~/.pr-gem')

    unless File.exist?(pr_gem_path)
      Dir.mkdir(pr_gem_path)
      puts '.pr-gem repository created successfully!'
    end

    if File.exist?(credentials_path)
      puts 'Credentials file already exists!'
      return
    end

    puts 'Please enter your OpenAI API key:'
    openai_token = STDIN.gets.chomp
    File.write(credentials_path, "OPENAI_TOKEN=#{openai_token}\n")
    puts 'Credentials file created successfully!'
  end

  def run
    puts 'Running pr-ai-gen...'
    fetch_diff
    load_template
    get_openai_token
    generate_pr_content
    print_content
  end

  private

  def parse_options(args)
    options = { target_branch: 'main', directory_location: File.expand_path("."), command: :run }

    if args[0] == 'init'
      options[:command] = :init
    elsif args[0] == 'generate'
      options[:command] = :run

      if args[1]
        options[:directory_location] = File.expand_path(args[1])
      end

      if args[2]
        local, target = args[2].split(':')
        options[:local_branch] = local
        options[:target_branch] = target || options[:target_branch]
      end
    else
      raise Exception.new "Invalid command!"
    end

    OptionParser.new do |opts|
      opts.banner = "Usage: pr-ai-gen <directory_location> <branch>:<target-branch=main>"

      opts.on("-h", "--help", "Prints this help") do
        puts opts
        exit
      end

    end.parse!(args)

    options
  end

  def fetch_diff
    # Start the ssh-agent in the background
    `eval $(ssh-agent -s)`

    # Add your SSH private key to the ssh-agent
    `ssh-add ~/.ssh/id_ed25519`
    ssh_keys = `ssh-add -l`

    if ssh_keys.include?('No identities')
      puts 'No SSH keys are added to the ssh-agent.'
      exit
    end

    @git_repo = Git.open(@options[:directory_location])
    @git_repo.fetch
    @git_repo.checkout(@options[:local_branch])
    @diff = @git_repo.diff(@options[:target_branch], @options[:local_branch])
  end

  def load_template
    template_path = File.join(@options[:directory_location], '.github', 'PULL_REQUEST_TEMPLATE.md')
    if File.exist?(template_path)
      @template = File.read(template_path)
    else
      @template = "# Default PR Template\n\n## Changes Made\n\nDescribe your changes in detail here."
    end
  end

  def get_openai_token
    credentials_path = File.expand_path('~/.pr-gem/credentials')
    if File.exist?(credentials_path)
      credentials = File.readlines(credentials_path).map(&:strip)
      @openai_token = credentials.find { |line| line.start_with?('OPENAI_TOKEN=') }
      raise "OpenAI credentials not found!" unless @openai_token
      @openai_token = @openai_token.split('=')[1]
    else
      raise "OpenAI credentials file not found!"
    end
  end

  def generate_pr_content
    puts "Generating PR content..."

    response = HTTParty.post(
      "#{OPEN_AI_URL}/chat/completions",
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{@openai_token}"
      },
      body: {
        model: "gpt-4-turbo-preview",
        messages: [
          {
            role: "user",
            content: "fill this templete:\n #{@template}\n with the following changes:\n #{@diff.to_s}"
          },
        ],
        max_tokens: 1024
      }.to_json
    )

    @pr_content = response.dig("choices", 0, "message", "content").strip

    puts "PR content generated successfully!"
  end

  def print_content
    puts "PR CONTENT FOLLOWING:"
    puts "BEGIN-------------------------------------------------------------------------"
    puts @pr_content
    puts "---------------------------------------------------------------------------END"
  end
end