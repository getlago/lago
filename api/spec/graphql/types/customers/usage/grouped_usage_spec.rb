# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Customers::Usage::GroupedUsage do
  subject { described_class }

  it do
    expect(subject).to have_field(:amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:pricing_unit_amount_cents).of_type("BigInt")
    expect(subject).to have_field(:events_count).of_type("Int!")
    expect(subject).to have_field(:units).of_type("Float!")
    expect(subject).to have_field(:filters).of_type("[ChargeFilterUsage!]")
    expect(subject).to have_field(:grouped_by).of_type("JSON")
    expect(subject).to have_field(:presentation_breakdowns).of_type("[PresentationBreakdownUsage!]")
  end
end
