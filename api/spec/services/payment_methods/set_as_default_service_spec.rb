# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentMethods::SetAsDefaultService do
  subject(:default_service) { described_class.new(payment_method:) }

  let(:required_permission) { "payment_methods:update" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:user) { membership.user }
  let(:payment_method) { create(:payment_method, customer:, organization:, is_default: false) }
  let(:payment_method2) { create(:payment_method, customer:, organization:, is_default: true) }
  let(:payment_method3) { create(:payment_method, customer:, organization:, is_default: false) }

  describe "#call" do
    context "when payment method exists" do
      before do
        payment_method
        payment_method2
        payment_method3
      end

      it "correctly sets default payment method" do
        default_service.call

        expect(payment_method.reload.is_default).to eq(true)
        expect(payment_method2.reload.is_default).to eq(false)
        expect(payment_method3.reload.is_default).to eq(false)
      end
    end

    context "when billing entity is nil" do
      let(:payment_method) { nil }

      it "returns a not found failure" do
        result = default_service.call
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("payment_method_not_found")
      end
    end
  end
end
