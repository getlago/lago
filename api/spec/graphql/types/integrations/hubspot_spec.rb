# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Integrations::Hubspot do
  subject { described_class }

  it do
    expect(subject).to have_field(:id).of_type("ID!")

    expect(subject).to have_field(:code).of_type("String!")
    expect(subject).to have_field(:connection_id).of_type("ID!")
    expect(subject).to have_field(:default_targeted_object).of_type("HubspotTargetedObjectsEnum!")
    expect(subject).to have_field(:name).of_type("String!")
    expect(subject).to have_field(:portal_id).of_type("String")

    expect(subject).to have_field(:invoices_object_type_id).of_type("String")
    expect(subject).to have_field(:subscriptions_object_type_id).of_type("String")

    expect(subject).to have_field(:sync_invoices).of_type("Boolean")
    expect(subject).to have_field(:sync_subscriptions).of_type("Boolean")
  end
end
