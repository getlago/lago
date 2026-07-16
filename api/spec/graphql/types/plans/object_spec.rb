# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Plans::Object do
  subject { described_class }

  it { is_expected.to have_field(:id).of_type("ID!") }
  it { is_expected.to have_field(:organization).of_type("Organization") }
  it { is_expected.to have_field(:amount_cents).of_type("BigInt!") }
  it { is_expected.to have_field(:amount_currency).of_type("CurrencyEnum!") }
  it { is_expected.to have_field(:bill_charges_monthly).of_type("Boolean") }
  it { is_expected.to have_field(:bill_fixed_charges_monthly).of_type("Boolean") }
  it { is_expected.to have_field(:code).of_type("String!") }
  it { is_expected.to have_field(:description).of_type("String") }
  it { is_expected.to have_field(:has_overridden_plans).of_type("Boolean") }
  it { is_expected.to have_field(:interval).of_type("PlanInterval!") }
  it { is_expected.to have_field(:invoice_display_name).of_type("String") }
  it { is_expected.to have_field(:minimum_commitment).of_type("Commitment") }
  it { is_expected.to have_field(:name).of_type("String!") }
  it { is_expected.to have_field(:parent).of_type("Plan") }
  it { is_expected.to have_field(:pay_in_advance).of_type("Boolean!") }
  it { is_expected.to have_field(:trial_period).of_type("Float") }
  it { is_expected.to have_field(:activity_logs).of_type("[ActivityLog!]") }
  it { is_expected.to have_field(:charges).of_type("[Charge!]") }
  it { is_expected.to have_field(:fixed_charges).of_type("[FixedCharge!]") }
  it { is_expected.to have_field(:taxes).of_type("[Tax!]") }
  it { is_expected.to have_field(:created_at).of_type("ISO8601DateTime!") }
  it { is_expected.to have_field(:updated_at).of_type("ISO8601DateTime!") }
  it { is_expected.to have_field(:deleted_at).of_type("ISO8601DateTime") }

  it { is_expected.to have_field(:usage_thresholds).of_type("[UsageThreshold!]") }

  it { is_expected.to have_field(:has_active_subscriptions).of_type("Boolean!") }
  it { is_expected.to have_field(:has_charges).of_type("Boolean!") }
  it { is_expected.to have_field(:has_customers).of_type("Boolean!") }
  it { is_expected.to have_field(:has_draft_invoices).of_type("Boolean!") }
  it { is_expected.to have_field(:has_fixed_charges).of_type("Boolean!") }
  it { is_expected.to have_field(:has_subscriptions).of_type("Boolean!") }

  it { is_expected.to have_field(:active_subscriptions_count).of_type("Int!") }
  it { is_expected.to have_field(:charges_count).of_type("Int!") }
  it { is_expected.to have_field(:fixed_charges_count).of_type("Int!") }
  it { is_expected.to have_field(:customers_count).of_type("Int!") }
  it { is_expected.to have_field(:draft_invoices_count).of_type("Int!") }
  it { is_expected.to have_field(:subscriptions_count).of_type("Int!") }
end
