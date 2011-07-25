#ENV["RAILS_ENV"] = "test"
#require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
gem 'rspec'
gem 'rspec-mocks'

# Load custom matchers
Dir[File.expand_path("#{File.dirname(__FILE__)}/matchers/*.rb")].uniq.each do |file|
  require file
end

=begin
Spec::Runner.configure do |config|
  config.use_transactional_fixtures = true
  config.use_instantiated_fixtures  = false
  config.global_fixtures = :users, :location

  config.before do
    User.current_user ||= users(:mikmck)
    Location.current_location = location(:martin_preuss_centre)
  end

end
=end