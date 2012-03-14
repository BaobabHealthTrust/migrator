

class Importer

  attr_reader :default_fields, :header_col, :csv_dir,
              :concept_map, :concept_name_map, :bart_url, :csv_file,
              :mapping_file_path

  include Migrator::Importable

  def initialize(csv_dir, mapping_file_path, restful=true)
    @default_fields = ['patient_id', 'encounter_id', 'workstation',
                       'date_created', 'encounter_datetime', 'provider_id',
                       'voided_by', 'date_voided', 'void_reason']
    #removed voided from default fields, so that we should identify voided records when
    #creating parameters

    @_header_concepts = nil
    @concept_map = nil
    @concept_name_map = nil
    @csv_dir = csv_dir + '/'
    @mapping_file_path = mapping_file_path + '/'
    @restful = restful

    @logger = Logger.new(STDOUT)
  end

   def create_encounter(row, obs_headers, bart_url, post_action)
    encounter_log = EncounterLog.find_by_encounter_id(row['encounter_id'])

    # skip successfully imported encounters
    if encounter_log.nil? or encounter_log.status != 1
      begin
        enc_params = self.params(row, obs_headers)
        if @restful
          new_id = post_params(post_action, enc_params, bart_url)
        else
          new_id = create_with_params(enc_params)
        end

        encounter_log = EncounterLog.new(:encounter_id => row['encounter_id'])
        encounter_log.status = 1
        encounter_log.patient_id = row['patient_id']
        encounter_log.description = new_id
        encounter_log.save
      rescue => error
        log "Failed to import encounter #{row['encounter_id']}. #{error.message}"
        encounter_log = EncounterLog.new(:encounter_id => row['encounter_id'])
        encounter_log.status = 0
        encounter_log.patient_id = row['patient_id']
        encounter_log.description = error.message
        encounter_log.save
      end
    end
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
