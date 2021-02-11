# frozen_string_literal: true

require 'rake/testtask'

desc 'Run app'
task :default do
  sh 'bundle exec ruby messier_tracker.rb'
end

desc 'Run tests'
task :test

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.test_files = FileList['test/**/*_test.rb']
end
