# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::IntegrationCustomers::Input do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:id).of_type("ID")
    expect(subject).to accept_argument(:external_customer_id).of_type("String")
    expect(subject).to accept_argument(:integration_type).of_type("IntegrationTypeEnum")
    expect(subject).to accept_argument(:integration_id).of_type("ID")
    expect(subject).to accept_argument(:integration_code).of_type("String")
    expect(subject).to accept_argument(:subsidiary_id).of_type("String")
    expect(subject).to accept_argument(:sync_with_provider).of_type("Boolean")
    expect(subject).to accept_argument(:targeted_object).of_type("HubspotTargetedObjectsEnum")
  end
end
