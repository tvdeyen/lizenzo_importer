require File.expand_path('../../config/application', __FILE__)

require 'rubygems'
require 'rake'
require 'rake/testtask'

desc "Default Task"
task :default => [ :spec ]

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new

require 'bundler'
Bundler::GemHelper.install_tasks
