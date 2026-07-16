# frozen_string_literal: true

require "rails_helper"

RSpec.describe Memberships::CreateService do
  subject(:create_service) { described_class.new(user:, organization:) }

  let(:user) { create(:user) }
  let(:organization) { create(:organization) }

  describe "#call" do
    it "creates a membership" do
      result = create_service.call

      expect(result).to be_success
      expect(result.membership.user_id).to eq(user.id)
      expect(result.membership.organization_id).to eq(organization.id)
    end

    context "when user does not exists" do
      let(:user) { nil }

      it "returns a result with error" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("user_not_found")
      end
    end

    context "when organization does not exists" do
      let(:organization) { nil }

      it "returns a result with error" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("organization_not_found")
      end
    end

    context "when user already has a membership in the organization" do
      before do
        create(:membership, user:, organization:)
      end

      it "returns a result with error" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error.messages[:user_id]).to include("value_already_exist")
      end
    end
  end
end
