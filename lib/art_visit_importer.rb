
class ArtVisitImporter < Importer

  # Create ART Visit Params from a CSV Encounter row
  def params(enc_row, obs_headers)
    # this has several post actions, so we will create each one separate
    params_array = []
    symptoms_array = []
    dosages_array = []
    adverse_effects_array = []
    prescription_params_array = []
    # initialise an array of symptoms as in Bart 2
    concepts_array = ['ABDOMINAL PAIN', 'ANOREXIA', 'COUGH','DIARRHEA','FEVER',
                      'ANEMIA', 'LACTIC ACIDOSIS', 'LIPODYSTROPHY', 'SKIN RASH',
                      'OTHER SYMPTOMS']
    effects_array = ['SKIN RASH','PERIPHERAL NEUROPATHY']
    exceptional_concepts_array = ['Prescription time period', 
                                  'Prescribe Cotrimoxazole (CPT)',
                                  'Prescribe Insecticide Treated Net (ITN)',
                                  'Prescribe recommended dosage',
                                  'Stavudine dosage',
                                  'Provider shown patient BMI',
                                  'Prescribed dose']

    av_params = init_params(enc_row, 'ART VISIT')
    ad_params = init_params(enc_row, 'ART ADHERENCE')
    outcome_params = init_params(enc_row, 'UPDATE OUTCOME')

    #prepare template for prescriptions
    prescription_params = {
      :patient_id=> enc_row['patient_id'],
      :type_of_prescription=>'variable',
      :duration=>'',
      :prn=>1,
      :morning_dose=>'',
      :afternoon_dose=>'',
      :evening_dose=>'',
      :night_dose=>'',
      :generic=>'',
      :dose_strength=>'',
      :formulation=>'',
      :auto=> '',
      :frequency=> '',
      :diagnosis=>'NO DIAGNOSIS',
      :location => enc_row['workstation'],
      :encounter_datetime => enc_row['encounter_datetime'],
      :imported_date_created => enc_row['date_created']
    }
    @void_params = {}

    obs_headers.each do |question|
      next if enc_row[question].blank?

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

      concept = Concept.find(@concept_name_map[question]) rescue nil
      next unless concept || exceptional_concepts_array.include?(question)

      unless exceptional_concepts_array.include?(question)
        quest_params = {
          :patient_id => enc_row['patient_id'],
          :concept_name => concept.fullname,
          :obs_datetime => enc_row['encounter_datetime'],
          :location_id => enc_row['workstation'],
          :value_coded => '',
          :value_coded_or_text => '',
          :value_coded_or_text_multiple => ''
        }
      end

      # To hold an array of params, in case we have multiple rows of a
      # particular observation
      rows_array = []

      #reset the post_destination variable: expected values: 1 =  Art_Visit
      # 2 = Adherence, 3 = Treatment, 4 = Outcome
      post_destination = 0

      case question
      when 'Hepatitis',
          'Refer patient to clinician', 'Weight loss',
          'Leg pain / numbness', 'Vomit', 'Jaundice','ARV regimen',
          'Is able to walk unaided', 'Is at work/school', 'Weight', 'Pregnant',
          'Other side effect', 'Continue ART',
          'Moderate unexplained wasting / malnutrition not responding to treatment (weight-for-height/ -age 70-79% or MUAC 11-12cm)',
          'Severe unexplained wasting / malnutrition not responding to treatment(weight-for-height/ -age less than 70% or MUAC less than 11cm or oedema)',
          'Prescribe ARVs this visit', 'Provider shown adherence data'
        rows_array = generate_params_array(quest_params,
                                           enc_row[question].to_s,question.to_s
                                          ) unless enc_row[question].to_s.empty?
        unless @void_params.blank?
          av_params = self.append_void_params(av_params,
                                               @void_params[:date_voided],
                                               @void_params[:void_reason],
                                               @void_params[:voided_by])
        end
        post_destination = 1
      when 'Total number of whole ARV tablets remaining',
           'Whole tablets remaining and brought to clinic',
           'Whole tablets remaining but not brought to clinic'
        rows_array_raw = generate_params_array(quest_params,
                                           enc_row[question].to_s,question.to_s
                                          ) unless enc_row[question].to_s.empty?
        rows_array = []
        rows_array_raw.each{ | element|
          if element[:value_drug]
            element[:value_drug] = @drug_oldid_newid_map[element[:value_drug]]
          end
        rows_array << element
        }

        unless @void_params.blank?
          ad_params = self.append_void_params(ad_params,
                                               @void_params[:date_voided],
                                               @void_params[:void_reason],
                                               @void_params[:voided_by])
        end
        
        post_destination = 2
      when 'Prescription time period',
           'Prescribe Cotrimoxazole (CPT)',
           'Prescribe Insecticide Treated Net (ITN)',
           'Prescribe recommended dosage', 'Stavudine dosage',
           'Provider shown patient BMI','Prescribed dose'
        if question == 'Prescribed dose'
          dosages_array = generate_dosage(enc_row[question].to_s)
        else
          prescription_params = update_prescription_parameters(
            prescription_params, enc_row[question].to_s,
            question.to_s) unless enc_row[question].to_s.empty?
        end

      when 	'Continue treatment at current clinic', 'Transfer out destination'
        rows_array = generate_params_array(quest_params,enc_row[question].to_s,
          question.to_s) unless enc_row[question].to_s.empty?

        unless @void_params.blank?
          outcome_params = self.append_void_params(outcome_params,
                                               @void_params[:date_voided],
                                               @void_params[:void_reason],
                                               @void_params[:voided_by])
        end

        post_destination = 4
      when  'TB status' #Special as this is saving value_coded_or_text in Bart2
        rows_array = get_tb_status(quest_params,
          enc_row[question].to_s) unless enc_row[question].to_s.empty?

        unless @void_params.blank?
          av_params = self.append_void_params(av_params,
                                               @void_params[:date_voided],
                                               @void_params[:void_reason],
                                               @void_params[:voided_by])
        end

        post_destination = 1
      end

      #Check if the symptom exists in the concepts_array
      if concepts_array.include?(question.upcase)
        unless enc_row[question].to_s.empty? #  TODO
          symptoms_array << question
        end
      end

      #Check if the symptom exists in the effects_array
      if effects_array.include?(question.upcase)
        unless enc_row[question].to_s.empty?
          adverse_effects_array << question
        end
      end


      #post the question to the right params holder
      rows_array.each do |row_params|
        if post_destination == 1
          av_params['observations[]'] << row_params
        elsif post_destination == 2
          ad_params['observations[]'] << row_params
        elsif post_destination == 4
          outcome_params['observations[]'] << row_params
        end
      end unless rows_array.empty?
    end #end of do
    #create the symptoms observation if the symptoms array is not empty
    unless symptoms_array.empty?
      symptoms_params = {
        :patient_id =>  enc_row['patient_id'],
        :concept_name => Concept.find_by_name('SYMPTOM PRESENT').fullname.upcase,
        :obs_datetime => enc_row['encounter_datetime'],
        :value_coded_or_text_multiple => symptoms_array
      }
      av_params['observations[]'] << symptoms_params
    end
    unless adverse_effects_array.empty?
      adverse_effects_params = {
        :patient_id =>  enc_row['patient_id'],
        :concept_name => Concept.find_by_name('ADVERSE EFFECT').fullname.upcase,
        :obs_datetime => enc_row['encounter_datetime'],
        :value_coded_or_text_multiple => adverse_effects_array
      }
      av_params['observations[]'] << adverse_effects_params
    end
    #creating prescriptions parameters array
    unless dosages_array.empty?
      dosages_array.each do |dosage|

        prescription = prescription_params.clone

        prescription[:generic] = @drug_oldid_newname_map[dosage[:drug_id]]
        prescription[:morning_dose] =  dosage[:morning_dose]
        prescription[:afternoon_dose] = dosage[:afternoon_dose]
        prescription[:evening_dose] = dosage[:evening_dose]
        prescription[:night_dose] = dosage[:night_dose]
        prescription[:formulation] = @drug_oldid_newname_map[dosage[:drug_id]]

        prescription_params_array << prescription

      end

    end

    params_array << av_params
    params_array << ad_params
    params_array << prescription_params_array
    outcome_params[:patient_program_id] = outcome_params["observations[]"][0][:patient_program_id] rescue nil
    outcome_params[:current_date] = outcome_params["observations[]"][0][:obs_datetime] rescue nil
    outcome_params[:current_state] = outcome_params["observations[]"][0][:current_state] rescue nil

    params_array << outcome_params

    return params_array
  end

  def split_string(string_value,split_character)
    split_value_array = string_value.split(split_character)
    return split_value_array
  end

  def generate_params_array(question_parameters, column_string,header_column)
    return_array = []
    generated_parameters = question_parameters

    all_rows_array = split_string(column_string,':') #split the column_string into rows (separated by ':')
    all_rows_array.each do |row_value|
      all_fields_array = split_string(row_value,';') #split the rows into an array of fields (separated by ';')
      all_fields_array.each do |field|
        field_value_pair = split_string(field,'-') #split the fields into 'field_name' and 'value' (separated by '-')
        generated_parameters[:"#{field_value_pair[0]}"] = field_value_pair[1]
      end
      case header_column
      when 'Continue treatment at current clinic', 'Transfer out destination'
        generated_parameters[:patient_program_id] = PatientProgram.find(:all,:conditions => ['patient_id = ?', generated_parameters[:patient_id]],:select => 'patient_program_id').first.patient_program_id.to_s
        generated_parameters[:current_state] = PatientProgram.find(generated_parameters[:patient_program_id]).patient_states.last.program_workflow_state.program_workflow_state_id
      end
      return_array << generated_parameters
    end
    return return_array
  end

  def get_tb_status(question_parameters, column_string)
    return_array = []
    generated_parameters = question_parameters

    all_rows_array = split_string(column_string,':') #split the column_string into rows (separated by ':')
    all_rows_array.each do |row_value|
      all_fields_array = split_string(row_value,';') #split the rows into an array of fields (separated by ';')
      all_fields_array.each do |field|
        field_value_pair = split_string(field,'-') #split the fields into 'field_name' and 'value' (separated by '-')
        case field_value_pair[1].to_i
        when 508
          generated_parameters[:value_coded_or_text] = "TB NOT SUSPECTED"
        when 479
          generated_parameters[:value_coded_or_text] = "TB SUSPECTED"
        when 478
          generated_parameters[:value_coded_or_text] = "CONFIRMED TB NOT ON TREATMENT"
        when 477
          generated_parameters[:value_coded_or_text] = "CONFIRMED TB ON TREATMENT"
        when 2
          generated_parameters[:value_coded_or_text] = "UNKNOWN"
        end
      end
      return_array << generated_parameters
    end
    return return_array
  end

  def update_prescription_parameters(question_parameters, column_string, actual_question)
    updated_parameters = question_parameters

    field_value_pair = split_string(column_string,'-') #split the fields into 'field_name' and 'value' (separated by '-')
    case actual_question
    when 'Prescription time period'
      case field_value_pair[1]
      when  '1 month'
        updated_parameters[:duration] = 30
      when  '2 months'
        updated_parameters[:duration] = 60
      when  '3 months'
        updated_parameters[:duration] = 90
      when  '4 months'
        updated_parameters[:duration] = 120
      when  '5 months'
        updated_parameters[:duration] = 150
      when  '6 months'
        updated_parameters[:duration] = 180
      when  '2 weeks'
        updated_parameters[:duration] = 14
      end
    when 'Prescribe Cotrimoxazole (CPT)'
      updated_parameters[:generic] = Drug.find(297).name
    when 'Prescribe Insecticide Treated Net (ITN)'
      #updated_parameters[:value_coded_or_text] = ''
    when 'Prescribe recommended dosage'
      #updated_parameters[:value_coded_or_text] = ''
    when 'Stavudine dosage'
      updated_parameters[:generic] = 'Stavudine'
    when 'Provider shown patient BMI'
      #updated_parameters[:value_coded_or_text] = ''
    end
    return updated_parameters
  end

  def generate_dosage(column_string)
    return_array = [] #to hold an array of formatted dosages
    dose_array = [] #to hold unformated dosages
    all_rows_array = split_string(column_string,':') #split the column_string into rows (separated by ':')
    all_rows_array.each do |row_value|
      dosage_params = init_dosage_params
      all_fields_array = split_string(row_value,';') #split the rows into an array of fields (separated by ';')
      all_fields_array.each do |field|
        field_value_pair = split_string(field,'-') #split the fields into 'field_name' and 'value' (separated by '-')
        case field_value_pair[0]
        when 'value_drug'
          dosage_params[:drug_id] = field_value_pair[1]
        when 'value_text'
          case field_value_pair[1]
          when  'Morning'
            dosage_params[:morning_dose] = 'current'
          when  'Noon'
            dosage_params[:afternoon_dose] = 'current'
          when  'Evening'
            dosage_params[:evening_dose] = 'current'
          when  'Night'
            dosage_params[:night_dose] = 'current'
          end
        when 'value_numeric'
          dosage_params[:morning_dose] = field_value_pair[1] if dosage_params[:morning_dose] == 'current'
          dosage_params[:afternoon_dose] = field_value_pair[1] if dosage_params[:afternoon_dose] == 'current'
          dosage_params[:evening_dose] = field_value_pair[1] if dosage_params[:evening_dose] == 'current'
          dosage_params[:night_dose] = field_value_pair[1] if dosage_params[:night_dose] == 'current'
        end
      end
      dose_array << dosage_params
    end
    dose_array.each do |dose|
      @found = false
      return_array << dose if return_array.empty?
      return_array.each do |values|
        if dose[:drug_id] == values[:drug_id]
          values[:morning_dose] = dose[:morning_dose] if dose[:morning_dose] != ''
          values[:afternoon_dose] = dose[:afternoon_dose] if dose[:afternoon_dose] != ''
          values[:evening_dose] = dose[:evening_dose] if dose[:evening_dose] != ''
          values[:night_dose] = dose[:night_dose] if dose[:night_dose] != ''
          @found = true
        end
      end
      return_array << dose if @found == false
    end
    return return_array #return formated array of dosages
  end

  def init_dosage_params
    dose_params = {}
    dose_params[:drug_id] = 0,
      dose_params[:afternoon_dose] = '',
      dose_params[:morning_dose]= '',
      dose_params[:evening_dose]= '',
      dose_params[:night_dose]= ''

    return dose_params
  end

  def create_encounter(row, obs_headers, bart_url, post_action)
    begin
      enc_params = params(row, obs_headers)
      if @restful
        #post params if an item in enc_params have observations
        new_id = post_params(post_action, enc_params[0], bart_url) unless enc_params[0]['observations[]'].empty?
        post_params(post_action, enc_params[1], bart_url) unless enc_params[1]['observations[]'].empty?
      else
        new_id = create_with_params(enc_params[0]) unless enc_params[0]['observations[]'].empty?
        create_with_params(enc_params[1]) unless enc_params[1]['observations[]'].empty?
      end

      puts "params0 empty" if enc_params[0]['observations[]'].empty?
      puts "params1 empty" if enc_params[1]['observations[]'].empty?

      unless enc_params[2].empty?
        enc_params[2].each do |prescription|
          post_params('prescriptions/create', prescription, bart_url)
        end
      else
        puts "params2 empty"
      end
      post_params('programs/update', enc_params[3], bart_url) unless enc_params[3]['observations[]'].empty?

      puts "params0 empty" if enc_params[3]['observations[]'].empty?

      puts "row#{row['encounter_id']}:#{row.to_csv}"
      encounter_log = EncounterLog.new(:encounter_id => row['encounter_id'])
      encounter_log.status = 1
      encounter_log.description = new_id
      #encounter_log.save
    rescue => error
      log "Failed to import encounter #{row['encounter_id']}. #{error.message}"
      puts "Failed to import encounter #{row['encounter_id']}. #{error.message}"
      encounter_log = EncounterLog.new(:encounter_id => row['encounter_id'])
      encounter_log.status = 0
      encounter_log.description = error.message
      #encounter_log.save
    end
  end

end
