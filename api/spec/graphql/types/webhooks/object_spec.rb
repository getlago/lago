# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Webhooks::Object do
  subject { described_class }

  it do
    expect(subject).to have_field(:id).of_type("ID!")
    expect(subject).to have_field(:webhook_endpoint).of_type("WebhookEndpoint")
    expect(subject).to have_field(:endpoint).of_type("String!")
    expect(subject).to have_field(:object_type).of_type("String!")
    expect(subject).to have_field(:retries).of_type("Int!")
    expect(subject).to have_field(:status).of_type("WebhookStatusEnum!")
    expect(subject).to have_field(:webhook_type).of_type("String!")
    expect(subject).to have_field(:http_status).of_type("Int")
    expect(subject).to have_field(:payload).of_type("String")
    expect(subject).to have_field(:response).of_type("String")
    expect(subject).to have_field(:created_at).of_type("ISO8601DateTime!")
    expect(subject).to have_field(:last_retried_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:updated_at).of_type("ISO8601DateTime!")
  end
end
