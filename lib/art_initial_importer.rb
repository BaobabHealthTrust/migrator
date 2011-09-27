
class ArtInitialImporter < Migrator::Importer

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
    enc_params = params(row, obs_headers)
    post_params(post_action, enc_params, bart_url)
  end
end
