# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Gocardless::Webhooks::MandateCancelledService do
  subject(:mandate_cancelled_service) { described_class.new(payment_provider:, mandate_id:) }

  let(:organization) { create(:organization) }
  let(:payment_provider) { create(:gocardless_provider, organization:) }
  let(:customer) { create(:customer, organization:) }
  let(:gocardless_customer) do
    create(
      :gocardless_customer,
      customer:,
      payment_provider:,
      provider_customer_id:,
      provider_mandate_id: mandate_id
    )
  end
  let(:payment_method) do
    create(
      :payment_method,
      customer:,
      payment_provider_customer: gocardless_customer,
      provider_method_id: mandate_id,
      payment_provider:
    )
  end

  let(:mandate_id) { "index_ID_123" }
  let(:provider_customer_id) { "CU123456" }

  describe "#call" do
    before do
      gocardless_customer
      payment_method
    end

    it "destroys the payment method for the customer" do
      expect { mandate_cancelled_service.call }.to change(PaymentMethod, :count).by(-1)
    end

    it "returns a successful result with the destroyed payment method" do
      result = mandate_cancelled_service.call

      expect(result).to be_success
      expect(result.payment_method).to be_present
      expect(result.payment_method.provider_method_id).to eq(mandate_id)
    end

    it "clears the gocardless customer provider_mandate_id" do
      mandate_cancelled_service.call

      expect(gocardless_customer.reload.provider_mandate_id).to be_nil
    end

    context "when payment method is not found" do
      let(:payment_method) do
        create(
          :payment_method,
          customer:,
          payment_provider_customer: gocardless_customer,
          provider_method_id: "test_unknown"
        )
      end

      it "does not destroy any payment method" do
        expect { mandate_cancelled_service.call }.not_to change(PaymentMethod, :count)
      end

      it "returns a successful result without payment method" do
        result = mandate_cancelled_service.call

        expect(result).to be_success
        expect(result.payment_method).to be_nil
      end
    end
  end
end
