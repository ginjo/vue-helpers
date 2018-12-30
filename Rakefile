require "bundler/gem_tasks"
require "rake/testtask"

# Adds cli options for minitest. These can also be passed from rake cli with TESTOPTS='-v ...'
# Also see https://chriskottom.com/blog/2014/12/command-line-flags-for-minitest-in-the-raw/
ENV['TESTOPTS'] ||= '-v'


Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
  
  # Rake 11 turns on ruby warnings by default.
  # This will turn them off again on the cli:
  #   RUBYOPT=W0
  # Also see https://github.com/hanami/utils/issues/123
  t.warning = false
end

task :default => :test
