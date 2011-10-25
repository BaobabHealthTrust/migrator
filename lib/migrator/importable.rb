# Import patient visits into BART2
#
#

module Migrator
  module Importable

    # Get params for encounter attributes
    def init_params(enc_row, type_name)
      enc_params = {}
      enc_params['encounter'] = {}
      enc_params['observations[]'] = []

      enc_params[:location] = enc_row['workstation']

      # encounter params
      enc_params['encounter']['patient_id'] = enc_row['patient_id']
      enc_params['encounter']['encounter_type_name'] = type_name

      # Include retired users
      enc_params['encounter']['provider_id'] = User.find_with_voided(
        enc_row['provider_id']).person.person_id rescue 1 
      enc_params['encounter']['encounter_datetime'] = enc_row['encounter_datetime']

      enc_params
    end

    #append void_params if the encounter was voided to use for voiding
    def append_void_params(enc_params, date_voided, void_reason, voiderer)
      enc_params['encounter']['voided'] = 1
      enc_params['encounter']['void_reason'] = void_reason
      enc_params['encounter']['date_voided'] = date_voided
      enc_params['encounter']['voided_by'] = voiderer

      enc_params
    end

    # Load mapping of old concepts to new ones
    # headers: old_concept_id, new_concept_id[, old_concept_name]
    def load_concepts(file='concept_map.csv')
      @concept_map = {}
      @concept_name_map = {}
      FasterCSV.foreach(@mapping_file_path + file, :headers => true) do |row|
        unless @concept_map[row['old_concept_id']]
          @concept_map[row['old_concept_id']] = row['new_concept_id']
          if row['old_concept_name']
            @concept_name_map[row['old_concept_name']] = row['new_concept_id']
          end
        end
      end
    end

    # Load all drugs mapped +file+
    # Default +file+ is +@csv_dir/drug_map.csv+
    def load_drugs(file='drug_map.csv')
      @drug_map = {}
      @drug_name_map = {}
      @drug_oldid_newname_map = {} #mapping old drug ids, to new Drug Names
      @drug_oldid_newid_map = {}
      FasterCSV.foreach(@mapping_file_path + file, :headers => true) do |row|
        unless @drug_map[row['drug_id']]
          @drug_map[row['drug_id']] = row['new_drug_id']
          if row['bart_one_name']
            @drug_name_map[row['bart_one_name']] = row['drug_id']
            @drug_oldid_newname_map[row['drug_id']] = row['bart_two_name']
            @drug_oldid_newid_map[row['drug_id']] = row['new_drug_id']
          end
        end
      end
    end

    def create_encounters(enc_file, bart_url)
      @bart_url = bart_url
      @csv_file = enc_file
      f = FasterCSV.read(@csv_dir + enc_file, :headers => true)
      obs_headers = f.headers - self.default_fields

      self.load_concepts unless @concept_map and @concept_name_map
      self.load_drugs unless @drug_map and @drug_name_map

      i = 1
      FasterCSV.foreach(@csv_dir + enc_file, :headers => true) do |row|

        post_action = 'encounters/create'
        self.create_encounter(row, obs_headers, bart_url, post_action)

        i += 1
      end

    end

    def post_params(post_action, enc_params, bart_url)
      #begin
        RestClient.post("http://#{bart_url}/#{post_action}",
                        enc_params)
      #rescue Exception => e
      #  raise "Migrator: Error while importing encounter #{e.message}"
      #  @logger.warn("Migrator: Error while importing encounter")
      #end
    end

  end
end