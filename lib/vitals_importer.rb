
class VitalsImporter < Importer

  # Create HIV Reception Params from a CSV Encounter row
  def params(enc_row, obs_headers)
    type_name = 'Vitals'
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
      end
      next if question == 'voided'

      concept = Concept.find(@concept_name_map[question]) rescue nil
      next unless concept
      quest_params = {
        :patient_id =>  enc_row['patient_id'],
        :concept_name => concept.fullname,
        :obs_datetime => enc_row['encounter_datetime'],
        :value_numeric => ''
      }

      case question
      when 'Height'
        quest_params[:value_numeric]  = enc_row[question]
        @currentHeight = enc_row[question].to_f

      when 'Weight'
        quest_params[:value_numeric]  = enc_row[question]
        @currentWeight = enc_row[question].to_f
      end
      enc_params['observations[]'] << quest_params
    end
    
    unless @currentHeight.blank? || @currentWeight.blank?
      @patient = Patient.find(enc_row['patient_id'])
      if PatientService.age(@patient.person).to_i < 15 #obs_headers.include?'Paediatric growth indicators' #calculate paediatric growth indicators
       age_in_months = PatientService.age_in_months(@patient.person)
       gender = @patient.person.gender
       medianweightheight = WeightHeightForAge.median_weight_height(age_in_months, gender).join(',') #rescue nil
       currentweightpercentile = (@currentWeight/(medianweightheight[0])*100).round(0)
       currentheightpercentile = (@currentHeight/(medianweightheight[1])*100).round(0)

        heightforage_params = {
          :patient_id =>  enc_row['patient_id'],
          :concept_name => Concept.find_by_name("HT FOR AGE").fullname,
          :obs_datetime => enc_row['encounter_datetime']
        }
        heightforage_params[:value_numeric]  = currentheightpercentile
        enc_params['observations[]'] << heightforage_params

        weightforage_params = {
          :patient_id =>  enc_row['patient_id'],
          :concept_name => Concept.find_by_name("WT FOR AGE").fullname,
          :obs_datetime => enc_row['encounter_datetime']
        }
        weightforage_params[:value_numeric]  = currentweightpercentile
        enc_params['observations[]'] << weightforage_params

        weightforheight_params = {
          :patient_id =>  enc_row['patient_id'],
          :concept_name => Concept.find_by_name("WT FOR HT").fullname,
          :obs_datetime => enc_row['encounter_datetime']
        }
        weightforheight_params[:value_numeric]  = calculate_weight_for_height(@currentHeight,@currentWeight)
        enc_params['observations[]'] << weightforheight_params


      elsif @currentHeight > 0 #calculate BMI
        bmi_params = {
          :patient_id =>  enc_row['patient_id'],
          :concept_name => Concept.find_by_name("BMI").fullname,
          :obs_datetime => enc_row['encounter_datetime']
        }

        bmi_params[:value_numeric] = (@currentWeight /
                                      (@currentHeight*@currentHeight) * 10000.0
                                     ).round(1)
        enc_params['observations[]'] << bmi_params
      end
    end
    enc_params
  end

  def calculate_weight_for_height(current_height,current_weight)
    current_height_rounded = (current_height % (current_height).round(0) < 0.5 ? 0 : 0.5) + (current_height).round(0)
    weight_for_heights = WeightForHeight.patient_weight_for_height_values.to_json
    median_weight_height = weight_for_heights[current_height_rounded.to_f.round(1)]
    weight_for_height_percentile = (current_weight/(median_weight_height)*100).round(0)

    return weight_for_height_percentile
  end

end
