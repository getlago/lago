# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wallets::RecurringTransactionRules::ValidateService do
  subject(:validate_service) { described_class.new(params:) }

  let(:params) do
    {
      trigger: "interval",
      interval: "weekly"
    }
  end

  describe "#call" do
    it "returns true" do
      expect(validate_service.call).to be_truthy
    end

    context "when invalid interval" do
      let(:params) do
        {
          trigger: "interval",
          interval: "invalid"
        }
      end

      it "returns false" do
        expect(validate_service.call).to be_falsey
      end
    end

    context "when invalid threshold" do
      let(:params) do
        {
          trigger: "threshold",
          threshold_credits: "invalid"
        }
      end

      it "returns false" do
        expect(validate_service.call).to be_falsey
      end
    end

    context "when invalid method" do
      let(:params) do
        {
          method: "target",
          trigger: "interval",
          interval: "weekly",
          target_ongoing_balance: "invalid"
        }
      end

      it "returns false" do
        expect(validate_service.call).to be_falsey
      end
    end

    context "when valid transaction_metadata" do
      let(:params) do
        {
          trigger: "interval",
          interval: "weekly",
          transaction_metadata: [{"key" => "valid_key", "value" => "invalid_value"}]
        }
      end

      it "returns true" do
        expect(validate_service.call).to eq true
      end
    end

    context "when invalid transaction_metadata" do
      let(:params) do
        {
          trigger: "interval",
          interval: "weekly",
          transaction_metadata: {"key" => "valid_key", "value" => "invalid_value"}
        }
      end

      it "returns false" do
        expect(validate_service.call).to eq false
      end
    end

    context "when invalid credits" do
      let(:params) do
        {
          trigger: "interval",
          interval: "weekly",
          paid_credits: "invalid"
        }
      end

      it "returns false" do
        expect(validate_service.call).to be_falsey
      end
    end

    describe "#valid_grants_target_top_up?" do
      context "when grants_target_top_up is true and method is target" do
        let(:params) do
          {
            method: "target",
            trigger: "interval",
            interval: "weekly",
            target_ongoing_balance: "100",
            grants_target_top_up: true
          }
        end

        it "returns true" do
          expect(validate_service.call).to eq true
        end
      end

      context "when grants_target_top_up is true and method is not target" do
        let(:params) do
          {
            method: "fixed",
            trigger: "interval",
            interval: "weekly",
            grants_target_top_up: true
          }
        end

        it "returns false" do
          expect(validate_service.call).to be_falsey
        end
      end

      context "when grants_target_top_up is false and method is not target" do
        let(:params) do
          {
            method: "fixed",
            trigger: "interval",
            interval: "weekly",
            grants_target_top_up: false
          }
        end

        it "returns false" do
          expect(validate_service.call).to be_falsey
        end
      end

      context "when grants_target_top_up is omitted" do
        let(:params) do
          {
            method: "fixed",
            trigger: "interval",
            interval: "weekly"
          }
        end

        it "returns true" do
          expect(validate_service.call).to eq true
        end
      end

      context "when grants_target_top_up is nil" do
        let(:params) do
          {
            method: "fixed",
            trigger: "interval",
            interval: "weekly",
            grants_target_top_up: nil
          }
        end

        it "returns true" do
          expect(validate_service.call).to eq true
        end
      end

      context "when grants_target_top_up is true but method is omitted from a partial update payload" do
        let(:params) do
          {
            trigger: "interval",
            interval: "weekly",
            grants_target_top_up: true
          }
        end

        it "returns false" do
          expect(validate_service.call).to be_falsey
        end
      end

      context "when grants_target_top_up is the string \"true\" and method is target" do
        let(:params) do
          {
            method: "target",
            trigger: "interval",
            interval: "weekly",
            target_ongoing_balance: "100",
            grants_target_top_up: "true"
          }
        end

        it "returns true" do
          expect(validate_service.call).to eq true
        end
      end

      context "when grants_target_top_up is the string \"true\" and method is not target" do
        let(:params) do
          {
            method: "fixed",
            trigger: "interval",
            interval: "weekly",
            grants_target_top_up: "true"
          }
        end

        it "returns false" do
          expect(validate_service.call).to be_falsey
        end
      end

      context "when grants_target_top_up is the string \"false\" and method is not target" do
        let(:params) do
          {
            method: "fixed",
            trigger: "interval",
            interval: "weekly",
            grants_target_top_up: "false"
          }
        end

        it "returns false" do
          expect(validate_service.call).to be_falsey
        end
      end
    end

    describe "#valid_target_above_threshold?" do
      context "when method is target, trigger is threshold and target is below threshold" do
        let(:params) do
          {
            method: "target",
            trigger: "threshold",
            target_ongoing_balance: "50",
            threshold_credits: "100"
          }
        end

        it "returns false" do
          expect(validate_service.call).to be_falsey
        end
      end

      context "when method is target, trigger is threshold and target equals threshold" do
        let(:params) do
          {
            method: "target",
            trigger: "threshold",
            target_ongoing_balance: "100",
            threshold_credits: "100"
          }
        end

        it "returns true" do
          expect(validate_service.call).to eq true
        end
      end

      context "when method is target, trigger is threshold and target is above threshold" do
        let(:params) do
          {
            method: "target",
            trigger: "threshold",
            target_ongoing_balance: "150",
            threshold_credits: "100"
          }
        end

        it "returns true" do
          expect(validate_service.call).to eq true
        end
      end

      context "when trigger is interval" do
        let(:params) do
          {
            method: "target",
            trigger: "interval",
            interval: "weekly",
            target_ongoing_balance: "50",
            threshold_credits: "100"
          }
        end

        it "ignores the threshold comparison and returns true" do
          expect(validate_service.call).to eq true
        end
      end
    end

    describe "#valid_expiration_at?" do
      context "when expiration_at is blank" do
        let(:params) do
          {
            trigger: "interval",
            interval: "weekly",
            expiration_at: nil
          }
        end

        it "returns true" do
          expect(validate_service.call).to eq true
        end
      end

      context "when expiration_at is an invalid format" do
        let(:params) do
          {
            trigger: "interval",
            interval: "weekly",
            expiration_at: "invalid-date"
          }
        end

        it "returns false" do
          expect(validate_service.call).to be_falsey
        end
      end

      context "when expiration_at is a past date" do
        let(:params) do
          {
            trigger: "interval",
            interval: "weekly",
            expiration_at: (Time.current - 1.hour).iso8601
          }
        end

        it "returns false" do
          expect(validate_service.call).to be_falsey
        end
      end

      context "when expiration_at is a valid future date" do
        let(:params) do
          {
            trigger: "interval",
            interval: "weekly",
            expiration_at: (Time.current + 1.hour).iso8601
          }
        end

        it "returns true" do
          expect(validate_service.call).to eq true
        end
      end
    end
  end
end
