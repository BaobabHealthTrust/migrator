
module Migrator
  class Importer

    attr_reader :default_fields, :header_col, :csv_dir,
                :concept_map, :concept_name_map, :bart_url, :csv_file

    include Migrator::Importable

    def initialize(csv_dir)
      @default_fields = ['patient_id', 'encounter_id', 'workstation',
                         'date_created', 'encounter_datetime', 'provider_id',
                         'voided', 'voided_by', 'date_voided', 'void_reason'
                         ]
      @_header_concepts = nil
      @concept_map = nil
      @concept_name_map = nil
      @csv_dir = csv_dir + '/'

      @logger = Logger.new(STDOUT)
    end
  end
end
