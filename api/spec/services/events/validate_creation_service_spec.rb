# frozen_string_literal: true

require "rails_helper"

RSpec.describe Events::ValidateCreationService do
  subject(:validate_event) do
    described_class.call(
      organization:,
      event_params:,
      customer:,
      subscriptions: [subscription]
    )
  end

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let!(:subscription) { create(:subscription, customer:, organization:) }
  let(:billable_metric) { create(:billable_metric, organization:) }
  let(:transaction_id) { SecureRandom.uuid }
  let(:event_params) do
    {external_subscription_id: subscription.external_id, code: billable_metric.code, transaction_id:}
  end

  describe ".call" do
    context "when customer has only one active subscription and external_subscription_id is not given" do
      it "does not return any validation errors" do
        result = validate_event
        expect(result).to be_success
      end
    end

    context "when customer has only one active subscription and customer is not given" do
      let(:event_params) do
        {code: billable_metric.code, external_subscription_id: subscription.external_id, transaction_id:}
      end

      it "does not return any validation errors" do
        result = validate_event
        expect(result).to be_success
      end
    end

    context "when customer has two active subscriptions" do
      before { create(:subscription, customer:, organization:) }

      let(:event_params) do
        {code: billable_metric.code, external_subscription_id: subscription.external_id, transaction_id:}
      end

      it "does not return any validation errors" do
        result = validate_event
        expect(result).to be_success
      end
    end

    context "when customer is not given but subscription is present" do
      let(:event_params) do
        {code: billable_metric.code, external_subscription_id: subscription.external_id, transaction_id:}
      end

      let(:validate_event) do
        described_class.call(
          organization:,
          event_params:,
          customer: nil,
          subscriptions: [subscription]
        )
      end

      it "does not return any validation errors" do
        result = validate_event
        expect(result).to be_success
      end
    end

    context "when there are two active subscriptions but external_subscription_id is not given" do
      let(:subscription2) { create(:subscription, customer:, organization:) }
      let(:event_params) { {code: billable_metric.code, transaction_id:} }

      let(:validate_event) do
        described_class.call(
          organization:,
          event_params:,
          customer:,
          subscriptions: [subscription, subscription2]
        )
      end

      it "returns a subscription_not_found error" do
        result = validate_event

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("subscription_not_found")
      end
    end

    context "when there are two active subscriptions but external_subscription_id is invalid" do
      let(:event_params) do
        {
          code: billable_metric.code,
          external_subscription_id: SecureRandom.uuid,
          external_customer_id: customer.external_id,
          transaction_id:
        }
      end

      let(:subscription2) { create(:subscription, customer:, organization:) }

      let(:validate_event) do
        described_class.call(
          organization:,
          event_params:,
          customer:,
          subscriptions: [subscription, subscription2]
        )
      end

      it "returns a not found error" do
        result = validate_event

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("subscription_not_found")
      end
    end

    context "when there is one active subscription with the same external_id" do
      let(:subscription) do
        create(:subscription, customer:, organization:, external_id:, status: :terminated)
      end
      let(:external_id) { SecureRandom.uuid }
      let(:event_params) do
        {
          code: billable_metric.code,
          external_subscription_id: external_id,
          external_customer_id: customer.external_id,
          transaction_id:
        }
      end

      before do
        subscription
        create(:subscription, customer:, organization:, external_id:)
      end

      it "does not return any validation errors" do
        result = validate_event
        expect(result).to be_success
      end
    end

    context "when transaction_id is already used" do
      before do
        create(
          :event,
          transaction_id:,
          external_subscription_id: subscription.external_id,
          subscription_id: subscription.id,
          organization_id: organization.id
        )
      end

      it "returns a validation error" do
        result = validate_event

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages.keys).to include(:transaction_id)
        expect(result.error.messages[:transaction_id]).to include("value_is_missing_or_already_exists")
      end
    end

    context "when code does not exist" do
      let(:event_params) do
        {external_subscription_id: subscription.external_id, code: "event_code", transaction_id:}
      end

      it "returns an event_not_found error" do
        result = validate_event

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("billable_metric_not_found")
      end
    end

    context "when field_name value is not a number" do
      let(:billable_metric) { create(:sum_billable_metric, organization:) }
      let(:event_params) do
        {
          code: billable_metric.code,
          external_subscription_id: subscription.external_id,
          properties: {
            item_id: "test"
          },
          transaction_id:
        }
      end

      it "returns an value_is_not_valid_number error" do
        result = validate_event

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages.keys).to include(:properties)
        expect(result.error.messages[:properties]).to include("value_is_not_valid_number")
      end

      context "when field_name cannot be found" do
        let(:event_params) do
          {
            code: billable_metric.code,
            external_subscription_id: subscription.external_id,
            properties: {
              invalid_key: "test"
            },
            transaction_id:
          }
        end

        it "does not raise error" do
          result = validate_event

          expect(result).to be_success
        end
      end

      context "when properties are missing" do
        let(:event_params) do
          {
            code: billable_metric.code,
            external_subscription_id: subscription.external_id,
            transaction_id:
          }
        end

        it "does not raise error" do
          result = validate_event

          expect(result).to be_success
        end
      end
    end

    context "when timestamp is in a wrong format" do
      let(:event_params) do
        {external_subscription_id: subscription.external_id, code: billable_metric.code, transaction_id:, timestamp: "2025-01-01"}
      end

      it "returns a timestamp_is_not_valid error" do
        result = validate_event

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages.keys).to include(:timestamp)
        expect(result.error.messages[:timestamp]).to include("invalid_format")
      end
    end

    context "when timestamp is valid" do
      let(:event_params) do
        {external_subscription_id: subscription.external_id, code: billable_metric.code, transaction_id:, timestamp: Time.current.to_i + 0.11}
      end

      it "does not raise any errors" do
        result = validate_event
        expect(result).to be_success
      end
    end
  end
end
