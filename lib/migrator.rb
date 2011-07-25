
require 'fastercsv'
require 'rest_client'
require 'migrator/exportable'
require 'migrator/importable'
require 'migrator/importer'
require 'encounter_exporter'
require 'reception_importer'
require 'art_initial_importer'
require 'hiv_staging_importer'
require 'vitals_importer'
require 'art_visit_importer'
require 'outcome_importer'
require 'dispensation_importer'

#m = EncounterExporter.new('/tmp/migrate', 6)
#m.to_csv

module Migrator
end