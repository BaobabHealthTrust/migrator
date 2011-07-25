# Export Encounters

require 'migrator/exportable'

class EncounterExporter

  attr_reader :forms, :type, :default_fields, :header_col, :limit,
              :csv_dir, :concept_map, :concept_name_map, :bart_url

  include Migrator::Exportable

  def initialize(csv_dir, encounter_type_id=nil, limit=100)
    @default_fields = ['patient_id', 'encounter_id', 'workstation',
                       'date_created', 'encounter_datetime', 'provider_id',
                       'voided', 'voided_by', 'date_voided', 'void_reason'
                       ]
    @_header_concepts = nil
    @concept_map = nil
    @concept_name_map = nil
    @csv_dir = csv_dir + '/'
    @limit = limit

    # Export mode
    if encounter_type_id
      @type = EncounterType.find(encounter_type_id) rescue nil
      @header_col = {}
    end

    @logger = Logger.new(STDOUT)
  end

end
