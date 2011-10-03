# Logs all encounters imported; successfully or not

class EncounterLog < ActiveRecord::Base

  attr_accessor :encounter_id, :status, :desc

  def initialize(encounter_id)
    self.encounter_id = encounter_id
    EncounterLog.create(:encounter_id => encounter_id)
  end

  def self.create_table
    sql = "CREATE TABLE encounter_log (
      id int AUTOINCREMENT,
      encounter_id int(11) NOT NULL DEFAULT 0,
      status int(1) NOT NULL DEFAULT 0;
      desc VARCHAR(255) DEFAULT NULL,
      PRIMARY KEY (`id`),
      KEY(encounter_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=latin1;"
    
    ActiveRecord::Base.connection.execute(sql)
  end

end
