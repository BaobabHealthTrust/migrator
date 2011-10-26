
class OutcomeImporter < Importer

  # Create Outcome/Patient state params from a CSV Encounter row
  def params(enc_row, obs_headers)
    @skip_record = false
    type_name = 'UPDATE OUTCOME'
    enc_params = init_params(enc_row, type_name)

    #append patient program id and patient state and current date to the main
    # parameters

    patient_program_id = PatientProgram.find(
      :first,
      :conditions => ['patient_id = ?', enc_row['patient_id']],
      :select => 'patient_program_id') rescue nil
    if patient_program_id != nil
      enc_params[:patient_program_id] = patient_program_id.patient_program_id.to_s
      enc_params[:current_state] = PatientProgram.find(patient_program_id).patient_states.last.program_workflow_state.program_workflow_state_id
      enc_params[:current_date] = enc_row['encounter_datetime']

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
        end
        next if question == 'voided'

        answer = enc_row[question].split(';').first if enc_row[question]
        next unless answer

        enc_params['observations[]'] << {
          :patient_id =>  enc_row['patient_id'],
          :concept_name => Concept.find(@concept_name_map[question]).fullname,
          :obs_datetime => enc_row['encounter_datetime'],
          :value_coded_or_text => Concept.find(@concept_map[answer]).fullname,
          :location => enc_row['location_id']
        }
      end
    else
       @skip_record = true
       log "Patient ID #{enc_row['patient_id']}  Encounter ID #{enc_row['encounter_id']}"
       
    end
    enc_params
  end

  def create_encounter(row, obs_headers, bart_url, post_action)
    begin
      enc_params = params(row,obs_headers)
      post_params('programs/update',enc_params,bart_url) if @skip_record == false
    rescue
      log "Failed to import encounter #{row['encounter_id']}"
    end
  end

end
