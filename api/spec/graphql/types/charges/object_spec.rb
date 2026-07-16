# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Charges::Object do
  subject { described_class }

  it do
    expect(subject).to have_field(:code).of_type("String")
    expect(subject).to have_field(:id).of_type("ID!")
    expect(subject).to have_field(:invoice_display_name).of_type("String")
    expect(subject).to have_field(:parent_id).of_type("ID")
    expect(subject).to have_field(:billable_metric).of_type("BillableMetric!")
    expect(subject).to have_field(:charge_model).of_type("ChargeModelEnum!")
    expect(subject).to have_field(:regroup_paid_fees).of_type("RegroupPaidFeesEnum")
    expect(subject).to have_field(:invoiceable).of_type("Boolean!")
    expect(subject).to have_field(:min_amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:pay_in_advance).of_type("Boolean!")
    expect(subject).to have_field(:properties).of_type("Properties")
    expect(subject).to have_field(:prorated).of_type("Boolean!")
    expect(subject).to have_field(:created_at).of_type("ISO8601DateTime!")
    expect(subject).to have_field(:deleted_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:updated_at).of_type("ISO8601DateTime!")
    expect(subject).to have_field(:taxes).of_type("[Tax!]")
    expect(subject).to have_field(:applied_pricing_unit).of_type("AppliedPricingUnit")
    expect(subject).to have_field(:filters).of_type("[ChargeFilter!]")
  end
end
