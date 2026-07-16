# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::PaymentMethods::Object do
  subject { described_class }

  it { is_expected.to have_field(:id).of_type("ID!") }

  it { is_expected.to have_field(:customer).of_type("Customer!") }
  it { is_expected.to have_field(:details).of_type("PaymentMethodDetails") }
  it { is_expected.to have_field(:is_default).of_type("Boolean!") }
  it { is_expected.to have_field(:payment_provider_code).of_type("String") }
  it { is_expected.to have_field(:payment_provider_customer_id).of_type("ID") }
  it { is_expected.to have_field(:payment_provider_type).of_type("ProviderTypeEnum") }
  it { is_expected.to have_field(:payment_provider_name).of_type("String") }
  it { is_expected.to have_field(:provider_method_id).of_type("String!") }

  it { is_expected.to have_field(:created_at).of_type("ISO8601DateTime!") }
  it { is_expected.to have_field(:deleted_at).of_type("ISO8601DateTime") }
  it { is_expected.to have_field(:updated_at).of_type("ISO8601DateTime") }
end
