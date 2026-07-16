# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Integrations::Hubspot::CreateInput do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:code).of_type("String!")
    expect(subject).to accept_argument(:name).of_type("String!")
    expect(subject).to accept_argument(:connection_id).of_type("String!")
    expect(subject).to accept_argument(:default_targeted_object).of_type("HubspotTargetedObjectsEnum!")
    expect(subject).to accept_argument(:sync_invoices).of_type("Boolean")
    expect(subject).to accept_argument(:sync_subscriptions).of_type("Boolean")
  end
end
