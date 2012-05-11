require 'rspec/core/rake_task'
require 'bundler/gem_tasks'

task :default => :spec

 desc 'Run ALL OF the specs'
 RSpec::Core::RakeTask.new(:spec) do |t|
    # t.ruby_opts = '-w'
   t.pattern = 'spec/*.rb'
 end