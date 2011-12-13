
class HivStagingImporter < Importer

  # Create HIV Staging Params from a CSV Encounter row
  def params(enc_row, obs_headers)
    type_name = 'HIV STAGING'
    enc_params = init_params(enc_row, type_name)

    obs_headers.each do |question|
      next if enc_row[question].blank?

      if question == 'voided'
        #append void parameters to the normal params
        begin
          voiderer = User.find(enc_row['voided_by']).id rescue 1

          enc_params = self.append_void_params(enc_params,
                                               enc_row['date_voided'],
                                               enc_row['void_reason'],
                                               voiderer)
        rescue
          log("failed to create void params for #{enc_row['encounter_id']}")
        end

        next
      end
      
      if question == 'Reason antiretrovirals started'
        concept = ConceptName.find_by_name('Reason antiretrovirals started').concept
      else
        concept = Concept.find(@concept_name_map[question]) rescue nil
      end

      next unless concept

      quest_params = {
        :patient_id   =>  enc_row['patient_id'],
        :concept_name => concept.fullname,
        :obs_datetime => enc_row['encounter_datetime'],
        :location_id => enc_row['location_id']
      }

      case question
      when "LYMPHOCYTE COUNT DATETIME", "CD4 COUNT DATETIME", "CD4 PERCENT DATETIME"
        quest_params[:value_datetime] = enc_row[question]
      when "CD4 PERCENT", "LYMPHOCYTE COUNT"
        quest_params[:value_numeric]  = enc_row[question]
      when "CLINICAL NOTES CONSTRUCT"
        quest_params[:value_text]     = enc_row[question]
      when "Reason antiretrovirals started"
        answer = @concept_map[enc_row[question]]
        quest_params[:value_coded] = answer
      else
        begin
          answer = @concept_map[enc_row[question].split(':').first]
          quest_params[:value_coded_or_text] = answer
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

end
