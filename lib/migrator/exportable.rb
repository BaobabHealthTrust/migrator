# == Migrator::Exportable
#
# Common methods for exporting encounters

module Migrator
  module Exportable

    def init_headers
      @_header_concepts = nil
      concepts = self.header_concepts
      concepts.each_with_index do |concept, col|
        @header_col[concept.concept_id] = col + @default_fields.length
      end

      # prefixing drug_ to prevent conflicts between concept_ids and drug_ids (22)
      self.header_drugs.each_with_index do |drug, col|
        @header_col["drug_#{drug.drug_id}"] = col + @default_fields.length +
                                    concepts.length
      end

    end
    # Dump concepts to CSV
    # headers: old_concept_id, new_concept_id, old_concept_name
    def dump_concepts(file='concept_map.csv')
      FasterCSV.open(@csv_dir + file, 'w',
          :headers => true) do |csv|
        csv << ['old_concept_id', 'old_concept_name', 'new_concept_id']
        Concept.all(:order => 'concept_id').each do |c|
          csv << [c.concept_id, c.name, @concept_map[c.concept_id.to_s].to_i]
        end
      end
    end

    # Get all headers using forms (INCOMPLETE!)
    def headers_by_forms
      @forms = @type.forms rescue nil
      @default_fields + @forms.first.fields.all(
          :order => 'field_number'
        ).map(&:concept).map(&:name)
    end

    # List of all headers including the default ones
    def headers
      fields = @default_fields + self.header_concepts.map(&:name)
      if @type.name == 'Give drugs'
        fields += self.header_drugs.map(&:name)
      end

      fields
    end

    # Get all concepts saved in all observations of this encounter type
    def header_concepts
      unless @_header_concepts
        @_header_concepts = Observation.all(
          :joins => [:encounter, :concept],
          :conditions => ['encounter_type = ?', @type.id],
          :group => 'concept.concept_id',
          :order => 'concept.concept_id').map(&:concept)

        if @type.name == 'HIV Staging'
          @_header_concepts << Concept.find_by_name('Reason antiretrovirals started')
        end
      end
      @_header_concepts
    end

    # Get all drugs dispensed in all drug orders
    def header_drugs
      DrugOrder.all(
        :joins => 'INNER JOIN orders USING(order_id)
                   INNER JOIN encounter USING(encounter_id)',
        :conditions => ['encounter_type = ?', @type.id],
        :group => 'drug_order.drug_inventory_id',
        :order => 'drug_order.drug_inventory_id'
      ).map(&:drug)
    end

    # New concept ids for this encounter type
    def new_header_ids
      self.header_concepts.map do |c|
        @concept_map[c.concept_id.to_s].to_i
      end if @concept_map
    end

    # Get value of given observation
    def obs_value(obs)
      return obs.attributes.collect{|name,value|
        next if value.nil? or value == "" or name !~ /value/
        value.to_s
      }.compact.join(";") rescue nil

    end

    #cloned from obs_value, I hope that this solves the Art Visit issue I am experiencing
    def obs_value_art_visit(obs)
      return obs.attributes.collect{|name,value|
        next if value.nil? or value == "" or name !~ /value/
        name.to_s + "-" + value.to_s
      }.compact.join(";") rescue nil
    end

    # Get void data if the given OpenMRS record is voided
    def set_void_info(record)
      void_info = {}
      if record and record.voided?
        void_info = {
          :voided => 1,
          :voided_by => record.voided_by,
          :date_voided => record.date_voided,
          :void_reason => record.void_reason
        }
      end
      void_info
    end

    # Export one encounter to one row of CSV
    def row(encounter)
      row = []
      row << encounter.patient_id
      row << encounter.encounter_id
      row << encounter.location_id #31 # TODO: workstation
      row << encounter.date_created
      row << encounter.encounter_datetime
      row << encounter.provider_id

      obs = Observation.all(:conditions => ['encounter_id = ?', encounter.id],
                            :order => 'concept_id')
      void_info = self.set_void_info(obs.first)
      if encounter.encounter_type == EncounterType.find_by_name('ART visit').encounter_type_id
        obs.each do |o|
          if row[@header_col[o.concept_id]].nil?
            row[@header_col[o.concept_id]] = obs_value_art_visit(o)
          else
            row[@header_col[o.concept_id]] += ":" + obs_value_art_visit(o)
          end
        end
      else
        obs.each do |o|
          if row[@header_col[o.concept_id]].nil?
            row[@header_col[o.concept_id]] = obs_value(o)
          else
            row[@header_col[o.concept_id]] += ":" + obs_value(o)
          end
        end
      end
      # Export drug orders for Give drugs encounters
      if @type.name == 'Give drugs'
        # order.voided, order.voided_by, order.date.voided
        # drug_order.drug_inventory_id, drug_order.quantity
        orders = Order.all(
            :select => 'orders.*, drug_order.drug_inventory_id,
                        SUM(drug_order.quantity) AS total_qty',
            :conditions => ['orders.encounter_id = ?', encounter.id],
            :joins => [:drug_orders, :encounter],
            :group => 'orders.encounter_id, drug_order.drug_inventory_id',
            :order => 'drug_inventory_id')
        set_void_info(orders.first) if void_info.blank?
        orders.each do |o|
          row[@header_col["drug_#{o.drug_inventory_id}"]] = o.total_qty
        end
      end

      # mark voided if it is
      unless void_info.blank?
        row[6] = void_info[:voided]
        row[7] = void_info[:voided_by]
        row[8] = void_info[:date_voided]
        row[9] = void_info[:void_reason]
      end

      row
    end

    # Export encounters of given type to csv
    def to_csv(out_file=nil)
      init_headers
      out_file = self.to_filename(@type.name) + '.csv' unless out_file
      out_file = @csv_dir + out_file
      FasterCSV.open(out_file, 'w',:headers => self.headers) do |csv|
        csv << self.headers
        Encounter.all(:conditions => ['encounter_type = ?', @type.id],
                      :limit => @limit, :order => 'encounter_id').each do |e|
          csv << self.row(e)
        end
      end
    end

    def to_filename(name)
      name.downcase.gsub(/[\/:\s]/, '_')
    end
      
  end
end
