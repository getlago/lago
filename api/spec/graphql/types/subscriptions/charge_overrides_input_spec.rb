# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Subscriptions::ChargeOverridesInput do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:applied_pricing_unit).of_type("AppliedPricingUnitOverrideInput")
    expect(subject).to accept_argument(:billable_metric_id).of_type("ID!")
    expect(subject).to accept_argument(:id).of_type("ID")
    expect(subject).to accept_argument(:filters).of_type("[ChargeFilterInput!]")
    expect(subject).to accept_argument(:invoice_display_name).of_type("String")
    expect(subject).to accept_argument(:min_amount_cents).of_type("BigInt")
    expect(subject).to accept_argument(:properties).of_type("PropertiesInput")
    expect(subject).to accept_argument(:tax_codes).of_type("[String!]")
  end
end
