# frozen_string_literal: true

require "rails_helper"

RSpec.describe Quotes::UpdateService do
  subject(:update_service) { described_class.new(quote:, params: update_params) }

  let(:organization) { create(:organization, feature_flags: ["order_forms"]) }
  let(:membership) { create(:membership, organization:) }
  let(:owner) { membership.user }
  let(:quote) { create(:quote, organization:) }
  let(:update_params) { {owners: [owner.id]} }

  describe ".call" do
    let(:result) { update_service.call }

    it "updates the quote", :premium do
      expect(result).to be_success
      expect(result.quote.id).to eq(quote.id)
      expect(result.quote.organization_id).to eq(quote.organization_id)
      expect(result.quote.customer_id).to eq(quote.customer_id)
      expect(result.quote.sequential_id).to eq(quote.sequential_id)
      expect(result.quote.number).to eq(quote.number)
      expect(result.quote.owner_ids).to eq([owner.id])
    end

    context "when owners include invalid user ids", :premium do
      let(:update_params) { {owners: ["invalid_user_id"]} }

      it "returns validation failure" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:owners]).to eq(["invalid"])
      end
    end

    context "when quote does not exist", :premium do
      let(:quote) { nil }

      it "returns a not found error" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("quote_not_found")
      end
    end

    context "when license is not premium" do
      it "returns forbidden status" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
        expect(result.error.code).to eq("feature_unavailable")
      end
    end
  end
end
