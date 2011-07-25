
class HivStagingImporter < Migrator::Importer

  # Create HIV Staging Params from a CSV Encounter row
  def params(enc_row, obs_headers)
    type_name = 'HIV STAGING'
    enc_params = init_params(enc_row, type_name)

    obs_headers.each do |question|
      next unless enc_row[question]
      concept = Concept.find(@concept_name_map[question]) rescue nil
      next unless concept
      quest_params = {
        :patient_id   =>  enc_row['patient_id'],
        :concept_name => Concept.find(@concept_name_map[question]).fullname,
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
        patient = Patient.find(enc_row['patient_id'])
        quest_params[:value_coded_or_text] = patient.reason_for_art_eligibility.concept_id
      else
        begin
          quest_params[:value_coded_or_text] = @concept_map[enc_row[question]]
        rescue
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
