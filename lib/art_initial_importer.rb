
class ArtInitialImporter < Importer

  # Create HIV Reception Params from a CSV Encounter row
  def params(enc_row, obs_headers=nil)
    type_name = 'ART_Initial'
    enc_params = init_params(enc_row, type_name)

    unless obs_headers
      f = FasterCSV.read(@csv_dir + enc_file, :headers => true)
      obs_headers = f.headers - self.default_fields
    end

    # program params
    enc_params['programs[]'] = []
    enc_params['programs[]'] << {
      'program_id' => Program.find_by_name('HIV PROGRAM').id,
      'date_enrolled' => enc_row['encounter_datetime'],
      'states[]' => {'state' => 'Pre-ART (Continue)'},
      'patient_program_id' => '',
      'location_id' => Location.current_health_center.id,
    }

    obs_headers.each do |question|
      next if enc_row[question].blank?
      concept = Concept.find(@concept_name_map[question]) rescue nil
      next unless concept


      quest_params = {
        :patient_id =>  enc_row['patient_id'],
        :concept_name => concept.fullname,
        :obs_datetime => enc_row['encounter_datetime']
      }

      case question
      when 'Date of positive HIV test', 'Date of ART initiation',
           'Date last ARVs taken'
        quest_params[:value_datetime] = enc_row[question]
      when 'Height', 'Weight'
        quest_params[:value_numeric]  = enc_row[question]
      when 'ARV number at that site'
        quest_params[:value_text]     = enc_row[question]
      when 'Location of first positive HIV test', 'Site transferred from',
           'Location of ART initiation'
        quest_params[:value_coded_or_text] = enc_row[question] # Location
      when 'Provider'
        enc_params['encounter']['provider_id'] = enc_row[question]
      else
        begin
          answer = @concept_map[enc_row[question].split(':').first]
          quest_params[:value_coded_or_text] = Concept.find(answer).concept_id
        rescue
          puts "****** Import failed: encounter #{enc_row['encounter_id']} " +
               "Q:#{question} A:#{enc_row[question]}****"
          next
        end
      end
      enc_params['observations[]'] << quest_params
    end

    enc_params
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
        encounter_log.description = new_id
        encounter_log.save
      rescue => error
        log "Failed to import encounter #{row['encounter_id']}"
        encounter_log = EncounterLog.new(:encounter_id => row['encounter_id'])
        encounter_log.status = 0
        encounter_log.description = error.message
        encounter_log.save
      end
    end
  end
  
end
