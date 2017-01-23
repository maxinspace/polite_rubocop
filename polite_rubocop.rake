Commit = Struct.new :hash, :email

# Fetches commits from git log
# Filters latest commits by given email
# Fetches a list of files for commits
class Commits
  def self.fetch(limit = 100)
    commits =
      `git log --pretty='%H %ae' -n #{limit}`
        .split("\n")
        .map { |line| commit line }
    new commits
  end

  def self.commit(line)
    hash, email = line.split ' '
    Commit.new hash, email
  end

  def initialize(commits)
    @commits = commits
  end

  def emails
    @commits.map(&:email)
  end

  def hashes
    @commits.map(&:hash)
  end

  def excluded_files
    excludes = YAML.load_file(".rubocop.yml")["AllCops"]["Exclude"]

    Dir.glob(excludes)
  end

  def all_files(exts = %w(.rb .rake))
    `git show --pretty=format: --name-only -r #{oneline}`
      .split("\n")
      .select { |file| File.exist? file }
      .uniq
      .grep(/#{one_of exts}$/)
  end

  def files
    all_files - excluded_files
  end

  def take_while_email_is(email)
    self.class.new @commits.take_while { |item| email == item.email }
  end

  private

  def oneline
    hashes.join ' '
  end

  def one_of(strings)
    parenthesize escape(strings).join('|')
  end

  def escape(strings)
    strings.map { |string| Regexp.escape string }
  end

  def parenthesize(string)
    "(#{string})"
  end
end

namespace :polite do
  desc "Polite syntax check for your latest commits"
  task :rubocop, [:options] => [:environment] do |t, args|
    require 'rubocop'

    commits = Commits.fetch
    files =
      commits
        .take_while_email_is(commits.emails.first)
        .files

    exit if files.size.zero?

    opts = [
      "--display-cop-names",
      "--rails",
      *files
    ]

    if args.to_a
      opts = args.to_a + opts
    end

    RuboCop::CLI.new.run opts
  end
end
