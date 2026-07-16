# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::IntegrationCustomers::Hubspot do
  subject { described_class }

  it do
    expect(subject).to have_field(:external_customer_id).of_type("String")
    expect(subject).to have_field(:id).of_type("ID!")
    expect(subject).to have_field(:integration_type).of_type("IntegrationTypeEnum")
    expect(subject).to have_field(:integration_id).of_type("ID")
    expect(subject).to have_field(:integration_code).of_type("String")
    expect(subject).to have_field(:targeted_object).of_type("HubspotTargetedObjectsEnum")
    expect(subject).to have_field(:sync_with_provider).of_type("Boolean")
  end
end
