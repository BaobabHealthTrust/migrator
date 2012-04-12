# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{migrator}
  s.version = "0.3.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.2") if s.respond_to? :required_rubygems_version=
  s.authors = ["Baobab Health"]
  s.date = %q{2012-02-12}
  s.description = %q{Migrate BART patient visit information}
  s.email = %q{developers@baobabhealth.org}
  s.extra_rdoc_files = ["LICENSE", "README.rdoc", "lib/art_initial_importer.rb",
                        "lib/art_visit_importer.rb",
                        "lib/dispensation_importer.rb",
                        "lib/encounter_exporter.rb", "lib/encounter_log.rb",
                        "lib/hiv_staging_importer.rb", "lib/migrator.rb",
                        "lib/migrator/exportable.rb",
                        "lib/migrator/importable.rb", "lib/importer.rb",
                        "lib/outcome_importer.rb", "lib/reception_importer.rb",
                        "lib/vitals_importer.rb"]
  s.files = ["LICENSE", "Manifest", "README.rdoc", "Rakefile",
             "lib/art_initial_importer.rb", "lib/art_visit_importer.rb",
             "lib/dispensation_importer.rb", "lib/encounter_exporter.rb",
             "lib/encounter_log.rb",
             "lib/hiv_staging_importer.rb", "lib/migrator.rb",
             "lib/migrator/exportable.rb", "lib/migrator/importable.rb",
             "lib/importer.rb", "lib/outcome_importer.rb", 
             "lib/reception_importer.rb", "lib/vitals_importer.rb",
             "spec/encounter_exporter_spec.rb", "spec/spec_helper.rb",
             "migrator.gemspec"]
  s.homepage = %q{http://github.com/baobabhealthtrust/migrator}
  s.rdoc_options = ["--line-numbers", "--inline-source", "--title", "Migrator",
                    "--main", "README.rdoc"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{migrator}
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{BART Migrator}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
