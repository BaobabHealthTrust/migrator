
class ReceptionImporter < Migrator::Importer

  # Create HIV Reception Params from a CSV Encounter row
  def params(enc_row, obs_headers)
    type_name = @csv_file == 'hiv_reception.csv' ? 'HIV Reception' :
                             'Outpatient Reception'
    enc_params = init_params(enc_row, type_name)

    obs_headers.each do |question|
      next unless enc_row[question]
      enc_params['observations[]'] << {
        :patient_id =>  enc_row['patient_id'],
        :concept_name => Concept.find(@concept_name_map[question]).fullname,
        :obs_datetime => enc_row['encounter_datetime'],
        :value_coded_or_text => Concept.find(@concept_map[enc_row[question]]).fullname,
        :location_id => enc_row['location_id']
      }
    end
    enc_params
  end

  def create_encounter(row, obs_headers, bart_url, post_action)
    enc_params = self.params(row, obs_headers)
    post_params(post_action, enc_params, bart_url)
  end

end
