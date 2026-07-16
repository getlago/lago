# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentMethods::DestroyService do
  subject(:destroy_service) { described_class.new(payment_method:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:membership) { create(:membership, organization:) }

  let(:payment_method) { create(:payment_method, organization:, customer:, is_default: true) }

  before { payment_method }

  describe "#call" do
    subject(:result) { destroy_service.call }

    context "when payment method is not found" do
      let(:payment_method) { nil }

      it "returns an error" do
        result = destroy_service.call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("payment_method_not_found")
      end
    end

    context "with payment method" do
      it "sets payment method as NOT default" do
        expect { destroy_service.call }
          .to change { payment_method.reload.is_default }
          .from(true)
          .to(false)
      end

      it "soft deletes the payment method" do
        freeze_time do
          expect { destroy_service.call }.to change(PaymentMethod, :count).by(-1)
            .and change { payment_method.reload.deleted_at }.from(nil).to(Time.current)
        end
      end
    end
  end
end
