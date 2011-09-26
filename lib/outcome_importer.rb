
class OutcomeImporter < Migrator::Importer

  # Create Outcome/Patient state params from a CSV Encounter row
  def params(enc_row, obs_headers)
    type_name = 'UPDATE OUTCOME'
    enc_params = init_params(enc_row, type_name)

    #append patient program id and patient state and current date to the main
    # parameters
    patient_program_id = PatientProgram.find(
      :first,
      :conditions => ['patient_id = ?', enc_row['patient_id']],
      :select => 'patient_program_id').patient_program_id.to_s
    enc_params[:patient_program_id] = patient_program_id
    enc_params[:current_state] = PatientProgram.find(patient_program_id).patient_states.last.program_workflow_state.program_workflow_state_id
    enc_params[:current_date] = enc_row['encounter_datetime']

    obs_headers.each do |question|
      next unless enc_row[question]

      enc_params['observations[]'] << {
        :patient_id =>  enc_row['patient_id'],
        :concept_name => Concept.find(@concept_name_map[question]).fullname,
        :obs_datetime => enc_row['encounter_datetime'],
        :value_coded_or_text => Concept.find(@concept_map[enc_row[question]]).fullname,
        :location => enc_row['location_id']
      }
    end
    enc_params
  end

  def create_encounter(row, obs_headers, bart_url, post_action)
    enc_params = params(row,obs_headers)
    post_params('programs/update',enc_params,bart_url)
  end
end
