# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Payments::Object do
  subject { described_class }

  it { is_expected.to have_field(:id).of_type("ID!") }

  it { is_expected.to have_field(:amount_cents).of_type("BigInt!") }
  it { is_expected.to have_field(:amount_currency).of_type("CurrencyEnum!") }

  it { is_expected.to have_field(:customer).of_type("Customer!") }
  it { is_expected.to have_field(:payable).of_type("Payable!") }
  it { is_expected.to have_field(:payable_payment_status).of_type("PayablePaymentStatusEnum") }
  it { is_expected.to have_field(:payment_method_id).of_type("ID") }
  it { is_expected.to have_field(:payment_provider).of_type("PaymentProvider") }
  it { is_expected.to have_field(:payment_provider_type).of_type("ProviderTypeEnum") }
  it { is_expected.to have_field(:payment_receipt).of_type("PaymentReceipt") }
  it { is_expected.to have_field(:payment_type).of_type("PaymentTypeEnum!") }
  it { is_expected.to have_field(:provider_payment_id).of_type("String") }
  it { is_expected.to have_field(:reference).of_type("String") }

  it { is_expected.to have_field(:created_at).of_type("ISO8601DateTime!") }
  it { is_expected.to have_field(:updated_at).of_type("ISO8601DateTime") }
end
