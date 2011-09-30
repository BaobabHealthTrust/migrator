

class Importer

  attr_reader :default_fields, :header_col, :csv_dir,
              :concept_map, :concept_name_map, :bart_url, :csv_file,
              :mapping_file_path

  include Migrator::Importable

  def initialize(csv_dir, mapping_file_path, restful=true)
    @default_fields = ['patient_id', 'encounter_id', 'workstation',
                       'date_created', 'encounter_datetime', 'provider_id',
                       'voided', 'voided_by', 'date_voided', 'void_reason']
    @_header_concepts = nil
    @concept_map = nil
    @concept_name_map = nil
    @csv_dir = csv_dir + '/'
    @mapping_file_path = mapping_file_path + '/'
    @restful = restful

    @logger = Logger.new(STDOUT)
  end

  # Create encounter RESTlessly using given params
  def create_with_params(enc_params)
    encounters = EncountersController.new
    encounters.create(HashWithIndifferentAccess.new(enc_params), {})
  end

  def log(msg)
    system("echo \"#{msg}\" >> #{RAILS_ROOT + '/log/import_errors.log'}")
  end
end
