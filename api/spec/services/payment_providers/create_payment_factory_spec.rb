# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::CreatePaymentFactory do
  subject(:new_instance) { described_class.new_instance(provider:, payment:, reference: "", metadata: {}) }

  let(:provider) { "stripe" }
  let(:payment) { create(:payment) }

  describe ".new_instance" do
    it "creates an instance of the stripe service" do
      expect(new_instance).to be_instance_of(PaymentProviders::Stripe::Payments::CreateService)
    end

    context "when provider is adyen" do
      let(:provider) { "adyen" }

      it "creates an instance of the adyen service" do
        expect(new_instance).to be_instance_of(PaymentProviders::Adyen::Payments::CreateService)
      end
    end

    context "when provider is gocardless" do
      let(:provider) { "gocardless" }

      it "creates an instance of the gocardless service" do
        expect(new_instance).to be_instance_of(PaymentProviders::Gocardless::Payments::CreateService)
      end
    end
  end
end
