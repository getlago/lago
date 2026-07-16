# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::OrderForms::Object do
  subject { described_class }

  it do
    expect(subject).to have_field(:id).of_type("ID!")
    expect(subject).to have_field(:number).of_type("String!")
    expect(subject).to have_field(:status).of_type("OrderFormStatusEnum!")
    expect(subject).to have_field(:void_reason).of_type("OrderFormVoidReasonEnum")
    expect(subject).to have_field(:billing_snapshot).of_type("JSON!")
    expect(subject).to have_field(:expires_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:signed_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:voided_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:signed_document_url).of_type("String")
    expect(subject).to have_field(:customer).of_type("Customer!")
    expect(subject).to have_field(:organization).of_type("Organization!")
    expect(subject).to have_field(:quote).of_type("Quote!")
    expect(subject).to have_field(:created_at).of_type("ISO8601DateTime!")
    expect(subject).to have_field(:updated_at).of_type("ISO8601DateTime!")
  end
end
