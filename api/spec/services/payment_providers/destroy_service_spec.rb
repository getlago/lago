# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::DestroyService do
  subject(:destroy_service) { described_class.new(payment_provider) }

  include_context "with mocked security logger"

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }

  let(:payment_provider) { create(:stripe_provider, organization:) }

  describe ".destroy" do
    before { payment_provider }

    it "destroys the payment_provider" do
      expect { destroy_service.call }
        .to change(PaymentProviders::BaseProvider, :count).by(-1)
    end

    it_behaves_like "produces a security log", "integration.deleted" do
      before { destroy_service.call }
    end

    context "when payment provider is not found" do
      let(:payment_provider) { nil }

      it "returns an error" do
        result = destroy_service.call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("payment_provider_not_found")
      end
    end
  end
end
