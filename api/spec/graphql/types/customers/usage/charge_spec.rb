# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Customers::Usage::Charge do
  subject { described_class }

  it do
    expect(subject).to have_field(:id).of_type("ID!")
    expect(subject).to have_field(:amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:events_count).of_type("Int!")
    expect(subject).to have_field(:units).of_type("Float!")
    expect(subject).to have_field(:billable_metric).of_type("BillableMetric!")
    expect(subject).to have_field(:charge).of_type("Charge!")
    expect(subject).to have_field(:grouped_usage).of_type("[GroupedChargeUsage!]!")
    expect(subject).to have_field(:filters).of_type("[ChargeFilterUsage!]")
    expect(subject).to have_field(:pricing_unit_amount_cents).of_type("BigInt")
  end
end
