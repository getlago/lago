# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Subscriptions::FixedChargeOverridesInput do
  subject { described_class }

  it { is_expected.to accept_argument(:id).of_type("ID") }
  it { is_expected.to accept_argument(:add_on_id).of_type("ID") }
  it { is_expected.to accept_argument(:apply_units_immediately).of_type("Boolean") }
  it { is_expected.to accept_argument(:invoice_display_name).of_type("String") }
  it { is_expected.to accept_argument(:properties).of_type("FixedChargePropertiesInput") }
  it { is_expected.to accept_argument(:tax_codes).of_type("[String!]") }
  it { is_expected.to accept_argument(:units).of_type("String") }
end
