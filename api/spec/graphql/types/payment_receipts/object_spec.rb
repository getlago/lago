# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::PaymentReceipts::Object do
  subject { described_class }

  it do
    expect(subject).to have_field(:id).of_type("ID!")

    expect(subject).to have_field(:file_url).of_type("String")
    expect(subject).to have_field(:number).of_type("String!")
    expect(subject).to have_field(:payment).of_type("Payment!")
    expect(subject).to have_field(:organization).of_type("Organization!")

    expect(subject).to have_field(:created_at).of_type("ISO8601DateTime!")
  end
end
