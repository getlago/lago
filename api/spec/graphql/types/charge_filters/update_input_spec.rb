# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::ChargeFilters::UpdateInput do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:id).of_type("ID!")
    expect(subject).to accept_argument(:cascade_updates).of_type("Boolean")
    expect(subject).to accept_argument(:invoice_display_name).of_type("String")
    expect(subject).to accept_argument(:properties).of_type("PropertiesInput")
  end
end
