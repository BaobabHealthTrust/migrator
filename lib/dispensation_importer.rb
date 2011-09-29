
class DispensationImporter < Migrator::Importer

  def create_encounter(enc_row, obs_headers, bart_url, post_action)
    obs_headers.each do |question|
      next unless enc_row[question]

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
            :imported_date_created=> enc_row['encounter_datetime']
          }
          post_params('dispensations/create', enc_params, bart_url)
        rescue
           log "Failed to import encounter #{row['encounter_id']}"
        end
      when 'Appointment date'
        begin
          enc_params = self.appointment_params(enc_row)
          post_params(post_action, enc_params, bart_url)
        rescue
          log "Failed to import encounter #{row['encounter_id']}"
        end
      else # dispensed drugs
        begin
          enc_params = {
            :patient_id => enc_row['patient_id'],
            :drug_id    => @drug_oldid_newid_map[@drug_name_map[question]],
            :quantity   => enc_row[question],
            :location => enc_row['workstation'],
            :imported_date_created=> enc_row['encounter_datetime']
          }
          post_params('dispensations/create', enc_params, bart_url)
        rescue
          log "Failed to import encounter #{row['encounter_id']}"
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
    enc_params
  end

  def log(msg)
    system("echo \"#{msg}\" >> #{RAILS_ROOT + '/log/import_errors.log'}")
  end

end
