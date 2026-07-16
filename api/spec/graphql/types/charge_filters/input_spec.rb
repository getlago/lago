# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::ChargeFilters::Input do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:invoice_display_name).of_type("String")
    expect(subject).to accept_argument(:properties).of_type("PropertiesInput!")
    expect(subject).to accept_argument(:values).of_type("ChargeFilterValues!")
  end
end
