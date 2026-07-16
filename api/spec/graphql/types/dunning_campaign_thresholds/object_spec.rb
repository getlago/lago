# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::DunningCampaignThresholds::Object do
  subject { described_class }

  it do
    expect(subject).to have_field(:id).of_type("ID!")

    expect(subject).to have_field(:amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:currency).of_type("CurrencyEnum!")
  end
end
