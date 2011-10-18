class DataUpdate < ActiveRecord::Base 

  bart_one = YAML.load(File.open(File.join(RAILS_ROOT, "config/database.yml"), "r"))['bart_one']
  self.establish_connection(bart_one) 


  set_table_name "person_attribute"
  set_primary_key "person_attribute_id"

  WHO_stage_four_peds = ConceptName.find_by_name("WHO stage IV peds")
  WHO_stage_three_peds = ConceptName.find_by_name("WHO stage III peds")
  WHO_stage_two_peds = ConceptName.find_by_name("WHO stage II peds")
  WHO_stage_one_peds = ConceptName.find_by_name("WHO stage I peds")
  WHO_stage_four_adult = ConceptName.find_by_name("WHO stage IV adult")
  WHO_stage_three_adult = ConceptName.find_by_name("WHO stage III adult")
  WHO_stage_two_adult = ConceptName.find_by_name("WHO stage II adult")
  WHO_stage_one_adult = ConceptName.find_by_name("WHO stage I adult")
  Less_than_250 = ConceptName.find_by_name("CD4 count less than 250")
  Less_than_350 = ConceptName.find_by_name("CD4 count less than 350")
  Less_than_25 = ConceptName.find_by_name("CD4 percent less than 25")
  Presumed_severe_HIV_criteria = ConceptName.find_by_name("PRESUMED SEVERE HIV CRITERIA IN INFANTS")
  PCR = ConceptName.find_by_name("HIV rapid test")

  Reason_for_art = ConceptName.find_by_name("Reason for ART eligibility")
  HIV_staging_encounter = EncounterType.find_by_name("HIV STAGING")

  def self.update_reason_for_art
    User.current_user = User.find(1)

    reasons = self.find(:all,:conditions =>["person_attribute_type_id=1"])
    (reasons || []).each do | reason |
      reason_value = reason.value.strip
      if reason_value == 'WHO stage 4 peds' or reason_value == 'Stage 4 peds'
        art_reason = WHO_stage_four_peds
      elsif reason_value == 'WHO stage 3 peds' or reason_value == 'Stage 3 peds'
        art_reason = WHO_stage_three_peds
      elsif reason_value == 'WHO stage 2 peds' or reason_value == 'Stage 2 peds'
        art_reason = WHO_stage_two_peds
      elsif reason_value== 'WHO stage 1 peds' or reason_value == 'Stage 1 peds'
        art_reason = WHO_stage_one_peds
      elsif reason_value== 'WHO stage 4 adult' or reason_value == 'Stage 4'
        art_reason = WHO_stage_four_adult
      elsif reason_value== 'WHO stage 3 adult' or reason_value== 'Stage 3'
        art_reason = WHO_stage_three_adult
      elsif reason_value== 'WHO stage 2 adult' or reason_value== 'Stage 2'
        art_reason = WHO_stage_two_adult
      elsif reason_value== 'WHO stage 1 adult' or reason_value== 'Stage 1'
        art_reason = WHO_stage_one_adult
      elsif reason_value == 'CD4 Count < 250' or reason_value== 'CD4  < 250'
        art_reason = Less_than_250
      elsif reason_value== 'CD4 Count < 350' or reason_value== 'CD4  < 350'
        art_reason = Less_than_350
      elsif reason_value == 'Presumed HIV Disease'
        art_reason = Presumed_severe_HIV_criteria
      elsif reason_value ==  'PCR Test'
        art_reason = PCR
      elsif reason_value == 'CD4 percentage < 25'
        art_reason = Less_than_25
      else
        puts ":::::::: not update #{reason.value}"
        next
      end

      encounter = Encounter.find(:first,:order => "encounter_datetime DESC",
                :conditions => ["patient_id = ? AND encounter_type = ?",
                reason.person_id,HIV_staging_encounter.id]) rescue nil
      next if encounter.blank?

      obs = Observation.new()
      obs.person_id = reason.person_id
      obs.encounter_id = encounter.id
      obs.obs_datetime = encounter.encounter_datetime
      obs.value_coded = art_reason.concept_id
      obs.value_coded_name_id = art_reason.id
      obs.concept_id = Reason_for_art.concept_id
      obs.save
      puts ">>>>>>>>>> #{art_reason.name}"
    end
    "Done ---"
  end

  def self.update_outcomes
    User.current_user = User.find(1)
    Location.current_location = Location.find(700)

    dispensed_encounter = Encounter.find(:all,:group =>"patient_id",
                          :order => "encounter_datetime ASC")

    program_ids = PatientProgram.find(:all,
                          :conditions => ["program_id = 1"])

    patient_ids = dispensed_encounter.collect{|p|p.patient_id}.join(',')
    patient_program_ids = program_ids.collect{|p|p.patient_program_id}.join(',')

    ActiveRecord::Base.connection.execute <<EOF                             
DELETE patient_state 
FROM patient_state  
INNER JOIN patient_program p 
ON p.patient_program_id = patient_state.patient_program_id
WHERE patient_state.state = 1
AND patient_state.patient_program_id IN (#{patient_program_ids})
AND p.patient_id IN (#{patient_ids});
EOF

    PatientProgram.find(:all,:conditions =>["program_id = 1 AND patient_id IN (?)
     AND date_completed IS NULL",patient_ids.split(',')]).each do | patient_program |
      state = PatientState.new()
      state.patient_program_id = patient_program.id
      state.state = 1
      state.start_date = patient_program.date_enrolled.to_date
      state.save
    end

     updating_state = nil 
     ProgramWorkflowState.find(:all).map do |state|
       next unless state.concept.fullname == "On antiretrovirals"
       next unless state.program_workflow_state_id == 7
       updating_state = state 
       break
     end

    (dispensed_encounter).each do | encounter |
     #next unless encounter.patient_id == 199
     patient = encounter.patient
      observations = Observation.find(:all,:order =>"obs_datetime ASC",
        :conditions => ["person_id = ? AND concept_id = ?",
        encounter.patient_id , 2834])

      (observations).each do | obs |
        arv = Drug.find(obs.value_drug).arv? rescue false
        if arv
          if self.current_hiv_state(patient,encounter.encounter_datetime) == "Pre-ART (Continue)"
            current = patient.patient_programs.current.local.collect{|p|p if p.program_id == 1}.last


            current_active_state = current.patient_states.last                
            current_active_state.end_date = obs.obs_datetime.to_date             
            
                                                                    
            patient_state = current.patient_states.build(                     
              :state => updating_state.program_workflow_state_id,                                       
              :start_date => obs.obs_datetime.to_date)                                   
            if patient_state.save                                                     
              # Close and save current_active_state if a new state has been created   
              current_active_state.save
              puts "close and created new state >>>>>>>>>>"
            end
            break
          end
        end
      end
    end
    "Done <<<<<<<<<<<<<"
  end

  def self.update_encounter_datetime
    records = ActiveRecord::Base.connection.select_all <<EOF                             
SELECT 
t2.patient_id bart1_patient_id,t2.encounter_id bart1_encounter_id,
t2.encounter_datetime bart1_encounter_datetime,
t2.date_created bart1_date_created,
t.patient_id bart2_patient_id,t.encounter_id bart2_encounter_id,
t.encounter_datetime bart2_encounter_datetime,
t.date_created bart2_date_created
FROM bart.encounter t,openmrs_mpc.encounter t2 
WHERE DATE(t.encounter_datetime) IN (
SELECT date(e.date_created) FROM openmrs_mpc.encounter e 
WHERE (e.encounter_datetime)=(t2.encounter_datetime) 
AND (DATE(e.date_created) <> DATE(e.encounter_datetime)) 
AND e.encounter_type IN(2) 
ORDER BY e.encounter_datetime
) AND t.encounter_type IN(25) 
AND t2.patient_id = t.patient_id 
GROUP BY t.encounter_ID
HAVING bart1_date_created = bart2_encounter_datetime
EOF

    (records).each do | record |
      bart1_encounter_date = record['bart1_encounter_datetime'].to_time.strftime('%Y-%m-%d %H:%M:%S')
      bart2_encounter_id = record['bart2_encounter_id'].to_i

      ActiveRecord::Base.connection.execute <<EOF                             
UPDATE encounter SET encounter_datetime = '#{bart1_encounter_date}'                        
WHERE encounter_id = #{bart2_encounter_id}                                      
EOF

      ActiveRecord::Base.connection.execute <<EOF                             
UPDATE obs SET obs_datetime = '#{bart1_encounter_date}'                        
WHERE encounter_id = #{bart2_encounter_id}                                      
EOF
      puts "updated >>>>>>>>>> encounter #: #{bart2_encounter_id}"
    end
    puts "Done <<<<<<<"
  end

  def self.updated_obs_and_encounter_dates
      ActiveRecord::Base.connection.execute <<EOF                             
UPDATE obs,encounter e SET obs.obs_datetime = e.encounter_datetime 
WHERE obs.encounter_id = e.encounter_id 
AND DATE(obs.obs_datetime) <> DATE(e.encounter_datetime)
EOF
  end

  def self.current_hiv_state(patient , outcome_date = Date.today)                              
    program_id = Program.find_by_name('HIV PROGRAM').id                         
    state = PatientState.find(:first,                                           
            :joins => "INNER JOIN patient_program p                             
            ON p.patient_program_id = patient_state.patient_program_id",        
            :conditions =>["patient_state.voided = 0 AND p.voided = 0           
            AND p.program_id = ? AND p.patient_id = ? AND start_date <= ?",     
            program_id,patient.patient_id,outcome_date.to_date],                   
            :order => "date_enrolled DESC,start_date DESC")                     
                                                                                
    state.program_workflow_state.concept.fullname rescue nil                    
  end

end
