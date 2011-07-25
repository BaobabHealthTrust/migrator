
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'migrator'

describe EncounterExporter do
  before(:each) do
    @exporter = EncounterExporter.new('lib/migrator', 5)
  end

  it "should get field headers" do
    @exporter.default_fields.should_not be_nil
    @exporter.headers.should_not be_nil
  end

  it "should get encounter row" do
    encounter = Encounter.find_by_encounter_type(@exporter.type.id)
    @exporter.row(encounter).should_not be_nil
  end

  it "should create the CSV file" do
    file = @exporter.type.name.gsub(' ', '_') + '.csv'
    @exporter.to_csv(file)
    File.exist?(@exporter.csv_dir + file).should be_true
  end

  it "should get observation's value" do
    o = Observation.new(:concept_id => 1, :value_coded => 3,
                        :value_numeric => 7)
    @exporter.obs_value(o).should == '3;7.0'
    o.value_coded = nil
    o.value_numeric = 7
    @exporter.obs_value(o).should == '7.0'
  end
end

