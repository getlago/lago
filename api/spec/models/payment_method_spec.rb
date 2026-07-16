# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentMethod do
  subject { build(:payment_method) }

  it_behaves_like "paper_trail traceable"

  it { is_expected.to belong_to(:organization) }
  it { is_expected.to belong_to(:customer) }
  it { is_expected.to belong_to(:payment_provider).class_name("PaymentProviders::BaseProvider").optional }
  it { is_expected.to belong_to(:payment_provider_customer).class_name("PaymentProviderCustomers::BaseCustomer").optional }

  it { expect(described_class).to be_soft_deletable }

  describe "Validations" do
    it "is not valid without payment_method_id" do
      subject.provider_method_id = nil

      expect(subject).not_to be_valid
    end
  end

  describe "Scopes" do
    describe ".default" do
      let(:pm1) { create(:payment_method, is_default: true) }
      let(:pm2) { create(:payment_method, is_default: true) }
      let(:pm3) { create(:payment_method, is_default: false) }

      before do
        pm1
        pm2
        pm3
      end

      it "lists only default payments" do
        default_payments = described_class.default

        expect(default_payments).to include(pm1, pm2)
        expect(default_payments).not_to include(pm3)
      end
    end
  end

  describe "#payment_provider_type" do
    subject(:payment_provider_type) { payment_method.payment_provider_type }

    let(:payment_method) { create(:payment_method, payment_provider:) }

    context "when payment provider is StripeProvider" do
      let(:payment_provider) { create(:stripe_provider) }

      it "returns stripe" do
        expect(payment_provider_type).to eq("stripe")
      end
    end

    context "when payment provider is nil" do
      let(:payment_provider) { nil }

      it "returns nil" do
        expect(payment_provider_type).to be_nil
      end
    end
  end
end
