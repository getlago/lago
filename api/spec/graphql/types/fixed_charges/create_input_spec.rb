# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::FixedCharges::CreateInput do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:plan_id).of_type("ID!")
    expect(subject).to accept_argument(:add_on_id).of_type("ID!")
    expect(subject).to accept_argument(:apply_units_immediately).of_type("Boolean")
    expect(subject).to accept_argument(:charge_model).of_type("FixedChargeChargeModelEnum!")
    expect(subject).to accept_argument(:code).of_type("String")
    expect(subject).to accept_argument(:invoice_display_name).of_type("String")
    expect(subject).to accept_argument(:pay_in_advance).of_type("Boolean")
    expect(subject).to accept_argument(:prorated).of_type("Boolean")
    expect(subject).to accept_argument(:units).of_type("String")
    expect(subject).to accept_argument(:properties).of_type("FixedChargePropertiesInput")
    expect(subject).to accept_argument(:tax_codes).of_type("[String!]")
  end
end
