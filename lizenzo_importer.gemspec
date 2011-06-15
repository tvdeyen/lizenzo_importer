# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "lizenzo_importer/version"

Gem::Specification.new do |s|
  s.name        = "lizenzo_importer"
  s.version     = LizenzoImporter::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Thomas von Deyen"]
  s.email       = ["tvdeyen@gmail.com"]
  s.homepage    = "https://github.com/tvdeyen/lizenzo_importer"
  s.summary     = %q{Imports lizenzo products from a CSV file into Spree.}
  s.description = %q{Imports lizenzo products from a CSV file into Spree.}
  
  s.rubyforge_project = "lizenzo_importer"
  
  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {spec}/*`.split("\n")
  s.require_paths = ["lib"]
  
  s.add_dependency('spree_core', '>= 0.30.1')
  s.add_dependency('delayed_job')
  
end
