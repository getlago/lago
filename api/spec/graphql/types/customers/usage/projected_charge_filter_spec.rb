# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Customers::Usage::ProjectedChargeFilter do
  subject { described_class }

  it do
    expect(subject).to have_field(:id).of_type("ID")
    expect(subject).to have_field(:amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:projected_amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:events_count).of_type("Int!")
    expect(subject).to have_field(:units).of_type("Float!")
    expect(subject).to have_field(:projected_units).of_type("Float!")
    expect(subject).to have_field(:invoice_display_name).of_type("String")
    expect(subject).to have_field(:pricing_unit_amount_cents).of_type("BigInt")
    expect(subject).to have_field(:pricing_unit_projected_amount_cents).of_type("BigInt")
    expect(subject).to have_field(:values).of_type("ChargeFilterValues!")
  end
end
