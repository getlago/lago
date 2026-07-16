# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::WebhookEndpoints::Object do
  subject { described_class }

  it do
    expect(subject).to have_field(:id).of_type("ID!")
    expect(subject).to have_field(:organization).of_type("Organization")
    expect(subject).to have_field(:webhook_url).of_type("String!")
    expect(subject).to have_field(:signature_algo).of_type("WebhookEndpointSignatureAlgoEnum")
    expect(subject).to have_field(:name).of_type("String")
    expect(subject).to have_field(:event_types).of_type("[EventTypeEnum!]")
    expect(subject).to have_field(:created_at).of_type("ISO8601DateTime!")
    expect(subject).to have_field(:updated_at).of_type("ISO8601DateTime!")
  end
end
