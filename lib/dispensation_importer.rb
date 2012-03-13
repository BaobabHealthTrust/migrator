
class DispensationImporter < Importer

  def create_encounter(enc_row, obs_headers, bart_url, post_action)
    @void_params = {}
    obs_headers.each do |question|
      next unless enc_row[question]

      if question == 'voided'
        #append void parameters to the normal params
        begin
          voiderer = User.find(enc_row['voided_by']).id rescue 1

          @void_params = {
            :date_voided => enc_row['date_voided'],
            :void_reason => enc_row['void_reason'],
            :voided_by =>  voiderer
          }
        rescue
          log("failed to create void params for #{enc_row['encounter_id']}")
        end
      end
      next if question == 'voided'

      enc_params = {}

      case question
      when 'Number of ARV tablets dispensed'
        next # TODO: find regimens for the first 15 dispensation at MPC

      when 'Number of CPT tablets dispensed'
        begin
          enc_params = {
            :patient_id => enc_row['patient_id'],
            :drug_id    => 297, # To check if this is the value that should be posted
            :quantity   => enc_row[question],
            :location => enc_row['workstation'],
            :encounter_datetime => enc_row['encounter_datetime'],
            :imported_date_created=> enc_row['date_created']
          }

          enc_params['encounter'] = {}

          unless @void_params.blank?
            enc_params = self.append_void_params(enc_params,
                                               @void_params[:date_voided],
                                               @void_params[:void_reason],
                                               @void_params[:voided_by])
          end

          post_params('dispensations/create', enc_params, bart_url)
        rescue
           log "Failed to import encounter #{enc_row['encounter_id']}"
        end
      when 'Appointment date'
        begin
          enc_params = self.appointment_params(enc_row)

          unless @void_params.blank?
            enc_params = self.append_void_params(enc_params,
                                               @void_params[:date_voided],
                                               @void_params[:void_reason],
                                               @void_params[:voided_by])
          end

          if @restful
            post_params(post_action, enc_params, bart_url)
          else
            create_with_params(enc_params)
          end
        rescue
          log "Failed to import encounter #{enc_row['encounter_id']}"
        end
      else # dispensed drugs
        begin
          enc_params = {
            :patient_id => enc_row['patient_id'],
            :drug_id    => @drug_oldid_newid_map[@drug_name_map[question]],
            :quantity   => enc_row[question],
            :location => enc_row['workstation'],
            :encounter_datetime => enc_row['encounter_datetime'],
            :imported_date_created=> enc_row['date_created']
          }

          enc_params['encounter'] = {}

          unless @void_params.blank?
            enc_params = self.append_void_params(enc_params,
                                               @void_params[:date_voided],
                                               @void_params[:void_reason],
                                               @void_params[:voided_by])
          end

          new_id = post_params('dispensations/create', enc_params, bart_url)
          encounter_log = EncounterLog.new(:encounter_id => enc_row['encounter_id'])
          encounter_log.status = 1
          encounter_log.description = new_id if new_id.class
          encounter_log.save
        rescue => error
          log "Failed to import encounter #{enc_row['encounter_id']}. #{error.message}"
          encounter_log = EncounterLog.new(:encounter_id => enc_row['encounter_id'])
          encounter_log.status = 0
          encounter_log.description = error.message
          encounter_log.save
        end
      end
    end

    nil
  end

  def appointment_params(enc_row)
    type_name = 'Appointment'
    enc_params = init_params(enc_row, type_name)

    visit_date = enc_row['encounter_datetime']
    enc_params['observations[]']
    question = 'Appointment date'
    if enc_row[question]
      appointment_date = enc_row[question].to_date
      enc_params['observations[]'] << {
        :patient_id =>  enc_row['patient_id'],
        :concept_name => 'RETURN VISIT DATE', # Concept.find(@concept_name_map[question]).fullname,
        :obs_datetime => visit_date,
        :value_datetime => appointment_date,
        :location_id => enc_row['location_id']
      }
      enc_params[:time_until_next_visit] = (appointment_date - visit_date.to_date).to_i/7
    end
    enc_params['encounter'] = {}
    enc_params
  end

end
