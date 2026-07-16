# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrderForms::VoidService do
  subject(:service) { described_class.new(order_form:) }

  let(:organization) { create(:organization, feature_flags: ["order_forms"]) }
  let(:customer) { create(:customer, organization:) }
  let(:quote) { create(:quote, organization:, customer:) }
  let(:quote_version) { create(:quote_version, :approved, organization:, quote:) }
  let(:order_form) { create(:order_form, customer:, organization:, quote_version:) }

  describe "#call" do
    context "when license is not premium" do
      it "returns a forbidden failure" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
        expect(result.error.code).to eq("feature_unavailable")
      end
    end

    context "with a premium license", :premium do
      context "when the order form does not exist" do
        let(:order_form) { nil }

        it "returns a not found failure" do
          result = service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.resource).to eq("order_form")
        end
      end

      context "with concurrent mutations" do
        it "wraps the work in a per-quote lock" do
          allow(Quotes::LockService).to receive(:call).and_call_original

          service.call

          expect(Quotes::LockService).to have_received(:call).with(quote: order_form.quote_version.quote).at_least(:once)
        end

        it "re-checks the status under the lock and refuses voiding an order form signed concurrently" do
          order_form
          OrderForm.find(order_form.id).update!(status: :signed, signed_at: Time.current)

          result = service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages).to eq({status: ["not_voidable"]})
        end
      end

      context "when the order form is not generated" do
        let(:order_form) { create(:order_form, :signed, customer:, organization:) }

        it "returns a validation failure" do
          result = service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages).to eq({status: ["not_voidable"]})
        end
      end

      context "when the order form is generated" do
        it "transitions the order form to voided" do
          result = service.call

          expect(result).to be_success
          expect(result.order_form).to be_voided
          expect(result.order_form.voided_at).to be_present
          expect(result.order_form.void_reason).to eq("manual")
        end

        it "cascades the void to the parent quote version" do
          service.call

          expect(quote_version.reload).to be_voided
          expect(quote_version.void_reason).to eq("cascade_of_voided")
        end
      end
    end
  end
end
