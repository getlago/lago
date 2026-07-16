# frozen_string_literal: true

require "rails_helper"

RSpec.describe Orders::UpdateService do
  subject(:service) { described_class.new(order:, params:) }

  let(:organization) { create(:organization, feature_flags: ["order_forms"]) }
  let(:customer) { create(:customer, organization:) }
  let(:order) { create(:order, organization:, customer:) }
  let(:params) { {execution_mode: "execute_in_lago", execute_at: 1.month.from_now.iso8601} }

  describe "#call" do
    context "without premium license" do
      it "returns a forbidden failure" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
        expect(result.error.code).to eq("feature_unavailable")
      end
    end

    context "with premium license", :premium do
      context "when order is nil" do
        let(:order) { nil }

        it "returns a not found failure" do
          result = service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.resource).to eq("order")
        end
      end

      context "when the order_forms feature flag is disabled" do
        let(:organization) { create(:organization) }

        it "returns a forbidden failure" do
          result = service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ForbiddenFailure)
        end
      end

      context "with concurrent mutations" do
        it "wraps the work in a per-quote lock" do
          allow(Quotes::LockService).to receive(:call).and_call_original

          service.call

          expect(Quotes::LockService).to have_received(:call).with(quote: order.quote).at_least(:once)
        end
      end

      context "when the order is already executed" do
        let(:order) { create(:order, :executed_in_lago, organization:, customer:) }
        let(:params) { {execution_mode: "order_only"} }

        it "returns a validation failure" do
          result = service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages).to eq({status: ["not_editable"]})
        end
      end

      context "when only execution_mode is provided" do
        let(:params) { {execution_mode: "order_only"} }

        it "updates the execution_mode and leaves execute_at blank" do
          result = service.call

          expect(result).to be_success
          expect(result.order.execution_mode).to eq("order_only")
          expect(result.order.execute_at).to be_nil
        end
      end

      context "when execution_mode and execute_at are provided" do
        let(:params) { {execution_mode: "execute_in_lago", execute_at: 1.month.from_now.iso8601} }

        it "updates both attributes on the order" do
          result = service.call

          expect(result).to be_success
          expect(result.order.execution_mode).to eq("execute_in_lago")
          expect(result.order.execute_at).to eq(Time.zone.parse(params[:execute_at]))
        end
      end

      context "when execute_at is provided without execution_mode and the order has none" do
        let(:params) { {execute_at: 1.month.from_now.iso8601} }

        it "returns a validation failure on execution_mode" do
          result = service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:execution_mode]).to eq(["value_is_mandatory"])
        end
      end

      context "when execute_at is provided and the order already has an execution_mode" do
        let(:order) { create(:order, organization:, customer:, execution_mode: "execute_in_lago") }
        let(:params) { {execute_at: 1.month.from_now.iso8601} }

        it "updates execute_at and keeps the existing execution_mode" do
          result = service.call

          expect(result).to be_success
          expect(result.order.execution_mode).to eq("execute_in_lago")
          expect(result.order.execute_at).to eq(Time.zone.parse(params[:execute_at]))
        end
      end

      context "when execution_mode is invalid" do
        let(:params) { {execution_mode: "unknown"} }

        it "returns a validation failure on execution_mode" do
          result = service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:execution_mode]).to eq(["value_is_invalid"])
        end
      end

      context "when execute_at is in the past" do
        let(:params) { {execution_mode: "execute_in_lago", execute_at: 1.day.ago.iso8601} }

        it "returns a validation failure on execute_at" do
          result = service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:execute_at]).to eq(["invalid_date"])
        end
      end

      context "when clearing execute_at while keeping an execution_mode" do
        let(:order) { create(:order, organization:, customer:, execution_mode: "execute_in_lago", execute_at: 1.month.from_now) }
        let(:params) { {execute_at: nil} }

        it "clears execute_at and keeps the execution_mode" do
          result = service.call

          expect(result).to be_success
          expect(result.order.execute_at).to be_nil
          expect(result.order.execution_mode).to eq("execute_in_lago")
        end
      end
    end
  end
end
