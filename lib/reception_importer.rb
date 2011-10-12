
class ReceptionImporter < Importer

  # Create HIV Reception Params from a CSV Encounter row
  def params(enc_row, obs_headers)
    type_name = @csv_file == 'hiv_reception.csv' ? 'HIV Reception' :
                             'Outpatient Reception'
    enc_params = init_params(enc_row, type_name)

    obs_headers.each do |question|
      next if enc_row[question].blank?
      concept = Concept.find(@concept_name_map[question]) rescue nil
      next unless concept

      answer = enc_row[question].split(':').first
      answer_concept = Concept.find(@concept_map[answer]) rescue nil
      next unless answer_concept
      
      enc_params['observations[]'] << {
        :patient_id =>  enc_row['patient_id'],
        :concept_name => concept.fullname,
        :obs_datetime => enc_row['encounter_datetime'],
        :value_coded_or_text => answer_concept.fullname,
        :location_id => enc_row['location_id']
      }
    end
    enc_params
  end

end
