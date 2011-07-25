require 'rubygems'
require 'rake'
require 'echoe'

Echoe.new('migrator', '0.1.0') do |p|
  p.summary    = 'BART Migrator'
  p.description    = 'Migrate BART patient visit information'
  p.url            = 'http://github.com/baobabhealthtrust/migrator'
  p.author         = 'Baobab Health'
  p.email          = 'developers@baobabhealth.org'
  p.ignore_pattern = ['tmp/*', 'nbproject/*', 'nbproject/*/*']
  p.development_dependencies = []
end

Dir["#{File.dirname(__FILE__)}/tasks/*.rake"].sort.each { |ext| load ext }

