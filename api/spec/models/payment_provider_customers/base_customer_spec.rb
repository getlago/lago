# frozen_string_literal: true

RSpec.describe PaymentProviderCustomers::BaseCustomer do
  subject(:integration_customer) { described_class.new(attributes) }

  let(:attributes) { {} }

  it { is_expected.to belong_to(:organization) }

  describe "#legacy_provider_method_id" do
    subject { customer.legacy_provider_method_id }

    context "when payment_method_id is set in settings" do
      let(:customer) { build(:stripe_customer, settings: {"payment_method_id" => "pm_123"}) }

      it { is_expected.to eq("pm_123") }
    end

    context "when only provider_mandate_id is set in settings" do
      let(:customer) { build(:gocardless_customer, settings: {"provider_mandate_id" => "mandate_123"}) }

      it { is_expected.to eq("mandate_123") }
    end

    context "when neither is set" do
      let(:customer) { build(:stripe_customer, settings: {}) }

      it { is_expected.to be_nil }
    end
  end
end
