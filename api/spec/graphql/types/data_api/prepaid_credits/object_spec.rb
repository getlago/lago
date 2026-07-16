# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::DataApi::PrepaidCredits::Object do
  subject { described_class }

  it do
    expect(subject.graphql_name).to eq("DataApiPrepaidCredit")

    expect(subject).to have_field(:amount_currency).of_type("CurrencyEnum!")

    expect(subject).to have_field(:purchased_amount).of_type("Float!")
    expect(subject).to have_field(:offered_amount).of_type("Float!")
    expect(subject).to have_field(:consumed_amount).of_type("Float!")
    expect(subject).to have_field(:voided_amount).of_type("Float!")

    expect(subject).to have_field(:purchased_credits_quantity).of_type("Float!")
    expect(subject).to have_field(:offered_credits_quantity).of_type("Float!")
    expect(subject).to have_field(:consumed_credits_quantity).of_type("Float!")
    expect(subject).to have_field(:voided_credits_quantity).of_type("Float!")

    expect(subject).to have_field(:end_of_period_dt).of_type("ISO8601Date!")
    expect(subject).to have_field(:start_of_period_dt).of_type("ISO8601Date!")
  end
end
