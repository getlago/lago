# frozen_string_literal: true

require "rails_helper"

RSpec.describe Quotes::CreateService do
  subject(:create_service) do
    described_class.new(
      organization:,
      customer:,
      subscription:,
      params: create_params
    )
  end

  let(:organization) { create(:organization, feature_flags: ["order_forms"]) }
  let(:membership) { create(:membership, organization:) }
  let(:owner) { membership.user }
  let(:customer) { create(:customer, organization:) }
  let(:subscription) { nil }
  let(:create_params) do
    {
      billing_items: {},
      content: "Test content",
      order_type: :subscription_creation,
      owners: [owner.id],
      currency: "USD",
      start_date:,
      end_date:
    }
  end
  let(:start_date) { Date.new(2025, 2, 11) }
  let(:end_date) { Date.new(2025, 3, 12) }

  describe ".call" do
    let(:result) { create_service.call }

    context "when license is premium", :premium do
      it "creates an empty draft quote" do
        travel_to(DateTime.new(2025, 3, 11, 20, 0, 0)) do
          expect(result).to be_success
          expect(result.quote.organization_id).to eq(organization.id)
          expect(result.quote.customer_id).to eq(customer.id)
          expect(result.quote.sequential_id).to eq(1)
          expect(result.quote.number).to eq("QT-2025-0001")
          expect(result.quote.order_type).to eq("subscription_creation")
          expect(result.quote.owner_ids).to eq([owner.id])

          expect(result.quote.versions.size).to eq(1)
          expect(result.quote.current_version.version).to eq(1)
          expect(result.quote.current_version.draft?).to eq(true)
          expect(result.quote.current_version.content).to eq("Test content")
          expect(result.quote.current_version.billing_items).to eq({})
          expect(result.quote.current_version.currency).to eq("USD")
          expect(result.quote.current_version.start_date).to eq(start_date)
          expect(result.quote.current_version.end_date).to eq(end_date)
        end
      end
    end

    context "when subscription is required and provided correctly", :premium do
      let(:subscription) { create(:subscription, organization:, customer:) }
      let(:create_params) do
        {
          billing_items: {},
          content: "Amendment",
          order_type: :subscription_amendment,
          owners: [owner.id]
        }
      end

      it "creates the quote linked to the subscription" do
        expect(result).to be_success
        expect(result.quote.subscription_id).to eq(subscription.id)
        expect(result.quote.order_type).to eq("subscription_amendment")
      end
    end

    context "when subscription belongs to another customer", :premium do
      let(:other_customer) { create(:customer, organization:) }
      let(:subscription) { create(:subscription, organization:, customer: other_customer) }
      let(:create_params) do
        {order_type: :subscription_amendment, owners: [owner.id]}
      end

      it "returns subscription_not_found" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("subscription_not_found")
      end
    end

    context "when subscription belongs to another organization", :premium do
      let(:other_organization) { create(:organization, feature_flags: ["order_forms"]) }
      let(:other_customer) { create(:customer, organization: other_organization) }
      let(:subscription) { create(:subscription, organization: other_organization, customer: other_customer) }
      let(:create_params) do
        {order_type: :subscription_amendment, owners: [owner.id]}
      end

      it "returns subscription_not_found" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("subscription_not_found")
      end
    end

    context "when owners include invalid user ids", :premium do
      let(:create_params) do
        {order_type: :subscription_creation, owners: ["invalid_user_id"]}
      end

      it "returns validation failure" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:owners]).to eq(["invalid"])
      end
    end

    context "when organization does not exist", :premium do
      let(:organization) { nil }
      let(:customer) { create(:customer) }
      let(:membership) { create(:membership) }

      it "returns a not found error" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("organization_not_found")
      end
    end

    context "when customer does not exist", :premium do
      let(:customer) { nil }

      it "returns a not found error" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("customer_not_found")
      end
    end

    context "when subscription is required but not provided", :premium do
      let(:create_params) { {order_type: "subscription_amendment"} }

      it "returns a not found error" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("subscription_not_found")
      end
    end

    context "when license is not premium" do
      it "returns forbidden status" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
        expect(result.error.code).to eq("feature_unavailable")
      end
    end

    context "when feature flag is disabled", :premium do
      let(:organization) { create(:organization) }

      it "returns forbidden status" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
        expect(result.error.code).to eq("feature_unavailable")
      end
    end
  end
end
