# frozen_string_literal: true

require "rails_helper"
require "rubocop"
require "rubocop/rspec/support"

# Load all custom cops
Dir[Rails.root.join("dev/cops/**/*.rb")].each do |file|
  require file
end

RSpec.configure do |config|
  config.include RuboCop::RSpec::ExpectOffense
end
