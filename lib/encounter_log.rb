# Logs all encounters imported; successfully or not

class EncounterLog < ActiveRecord::Base

  set_table_name 'encounter_log'
  attr_accessible :encounter_id, :status, :description, :patient_id

  def self.create_table
    sql = "CREATE TABLE encounter_log (
      id int(11) NOT NULL AUTO_INCREMENT,
      encounter_id int(11) NOT NULL DEFAULT 0,
      patient_id int(11) NOT NULL DEFAULT 0,
      status int(1) NOT NULL DEFAULT 0,
      description VARCHAR(255) DEFAULT NULL,
      PRIMARY KEY (`id`),
      KEY(encounter_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=latin1"
    
    ActiveRecord::Base.connection.execute(sql)
  end

  def self.drop_table
    ActiveRecord::Base.connection.execute("DROP TABLE encounter_log")
  end

end
