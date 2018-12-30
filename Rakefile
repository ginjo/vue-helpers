require "bundler/gem_tasks"
require "rake/testtask"

# Adds cli options for minitest. These can also be passed from rake cli with TESTOPTS='-v ...'
# Also see https://chriskottom.com/blog/2014/12/command-line-flags-for-minitest-in-the-raw/
ENV['TESTOPTS'] = '-v'


Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

task :default => :test
