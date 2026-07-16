# frozen_string_literal: true

require "rails_helper"

RSpec.describe BillableMetrics::EvaluateExpressionService do
  subject(:evaluate_service) { described_class.new(expression:, event:) }

  let(:expression) { "round(event.properties.value * event.properties.units)" }
  let(:event) do
    {
      "code" => "test_code",
      "timestamp" => Time.current.to_i,
      "properties" => {
        "value" => 10.4,
        "units" => 2
      }
    }
  end

  describe "#call" do
    it "returns the result of the evaluated expression" do
      result = evaluate_service.call

      expect(result).to be_success
      expect(result.evaluation_result).to eq(21.0)
    end

    context "when the expression is missing" do
      let(:expression) { nil }

      it "returns a validation error" do
        result = evaluate_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:expression]).to include("value_is_mandatory")
      end
    end

    context "when the expression is invalid" do
      let(:expression) { "invalid_expression" }

      it "returns a validation error" do
        result = evaluate_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:expression]).to include("invalid_expression")
      end
    end

    context "when timestamp is missing" do
      let(:expression) { "event.timestamp" }
      let(:event) do
        {
          "code" => "test_code",
          "properties" => {}
        }
      end

      it "uses current time as fallback" do
        freeze_time do
          result = evaluate_service.call

          expect(result).to be_success
          expect(result.evaluation_result).to eq(Time.current.to_i)
        end
      end
    end

    context "when the event failed to evaluate" do
      let(:event) do
        {
          "code" => "test_code",
          "timestamp" => Time.current.to_i,
          "properties" => {
            "value" => "invalid_value",
            "units" => 2
          }
        }
      end

      it "returns a validation error" do
        result = evaluate_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:event]).to include("invalid_event")
      end

      context "when the event is missing" do
        let(:event) { nil }

        it "returns a validation error" do
          result = evaluate_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:event]).to include("invalid_event")
        end
      end
    end
  end
end
