# frozen_string_literal: true

require "rails_helper"
RSpec.describe Coupons::ValidateService do
  subject(:validate_service) { described_class.new(result, **args) }

  let(:result) { BaseService::Result.new }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:expiration_at) { Time.current + 10.days }
  let(:args) do
    {
      organization_id: organization.id,
      name: "name",
      code: "code",
      coupon_type: "fixed_amount",
      amount_cents: 100,
      amount_currency: "EUR",
      frequency: "once",
      expiration: "time_limit",
      expiration_at:
    }
  end

  describe "#valid?" do
    it "returns true" do
      expect(validate_service).to be_valid
    end

    context "when expiration_at is invalid" do
      let(:expiration_at) { Time.current - 10.days }

      it "returns false and result has errors" do
        expect(validate_service).not_to be_valid
        expect(result.error.messages[:expiration_at]).to eq(["invalid_date"])
      end
    end
  end
end
