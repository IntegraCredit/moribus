ENV["RAILS_ENV"] ||= 'test'

require "simplecov" unless ENV['CI']

require File.expand_path("../../spec/dummy/config/environment", __FILE__)
require "rspec/rails"
require "rspec/autorun"
require "moribus"

Dir["./spec/support/**/*.rb"].sort.each { |f| require f }

RSpec.configure do |config|
  config.mock_with :rspec
  config.use_transactional_fixtures = true
end
