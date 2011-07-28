# Export Encounters

require 'migrator/exportable'

class EncounterExporter

  attr_reader :forms, :type_id, :default_fields, :header_col, :limit, :csv_dir, :patient_list

  include Migrator::Exportable

  def initialize(csv_dir, encounter_type_id=nil, limit=10, patient_list=nil)
    @default_fields = ['patient_id', 'encounter_id', 'workstation',
                       'date_created', 'encounter_datetime', 'provider_id',
                       'voided', 'voided_by', 'date_voided', 'void_reason'
                       ]
    @_header_concepts = nil
    @concept_map = nil
    @concept_name_map = nil
    @csv_dir = csv_dir + '/'
    @limit = limit
    @patient_list = patient_list

    @type_id = encounter_type_id #EncounterType.find(encounter_type_id) #rescue nil
    @header_col = {}

  end

end
