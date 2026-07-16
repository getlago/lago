# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::DunningCampaigns::Object do
  subject { described_class }

  it do
    expect(subject).to have_field(:id).of_type("ID!")

    expect(subject).to have_field(:customers_count).of_type("Int!")
    expect(subject).to have_field(:applied_to_organization).of_type("Boolean!")
    expect(subject).to have_field(:bcc_emails).of_type("[String!]")
    expect(subject).to have_field(:code).of_type("String!")
    expect(subject).to have_field(:days_between_attempts).of_type("Int!")
    expect(subject).to have_field(:max_attempts).of_type("Int!")
    expect(subject).to have_field(:name).of_type("String!")
    expect(subject).to have_field(:thresholds).of_type("[DunningCampaignThreshold!]!")

    expect(subject).to have_field(:description).of_type("String")

    expect(subject).to have_field(:created_at).of_type("ISO8601DateTime!")
    expect(subject).to have_field(:updated_at).of_type("ISO8601DateTime!")
  end
end
