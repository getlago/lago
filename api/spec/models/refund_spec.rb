# frozen_string_literal: true

require "rails_helper"

RSpec.describe Refund do
  subject(:refund) { build(:refund) }

  describe "enums" do
    it do
      expect(subject).to define_enum_for(:reason)
        .backed_by_column_of_type(:string)
        .with_values(described_class::REASONS)
        .validating(allowing_nil: true)
    end
  end

  describe "associations" do
    it do
      expect(subject).to belong_to(:payment)
      expect(subject).to belong_to(:credit_note).optional
      expect(subject).to belong_to(:payment_provider).class_name("PaymentProviders::BaseProvider").optional
      expect(subject).to belong_to(:payment_provider_customer).class_name("PaymentProviderCustomers::BaseCustomer")
      expect(subject).to belong_to(:organization)

      association = described_class.reflect_on_association(:refundable)
      expect(association.macro).to eq(:belongs_to)
      expect(association.options).to include(polymorphic: true, optional: true)
    end
  end

  describe "validations" do
    it "requires a refundable when the refund is not linked to a credit note" do
      refund.credit_note = nil
      refund.refundable = nil
      expect(refund).not_to be_valid
      expect(refund.errors.added?(:refundable, :blank)).to be(true)
    end

    it "allows legacy credit-note refunds without a refundable association" do
      refund.credit_note = create(:credit_note)
      refund.refundable = nil
      expect(refund).to be_valid
    end

    it "allows activation-expired refunds without a credit note" do
      activation_refund = build(:subscription_activation_expired_refund)
      expect(activation_refund).to be_valid
      expect(activation_refund.credit_note).to be_nil
      expect(activation_refund.refundable).to be_closed
      expect(activation_refund.reason).to eq("subscription_activation_expired")
    end

    it "is valid with an unpersisted credit note" do
      expect(build(:refund, refundable: nil)).to be_valid
    end
  end
end
