# frozen_string_literal: true

require "rails_helper"
RSpec.describe Invites::ValidateService do
  subject(:validate_service) { described_class.new(result, **args) }

  let(:result) { BaseService::Result.new }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:user) { membership.user }
  let(:args) do
    {
      current_organization: organization,
      email: Faker::Internet.email,
      roles: %w[admin]
    }
  end

  before { create(:role, :admin) }

  describe "#valid?" do
    it "returns true" do
      expect(validate_service).to be_valid
    end

    context "when invite already exists" do
      before { create(:invite, email: user.email, recipient: membership, organization:) }

      let(:args) do
        {
          current_organization: organization,
          email: user.email,
          roles: %w[admin]
        }
      end

      it "returns false and result has errors" do
        expect(validate_service).not_to be_valid
        expect(result.error.messages[:invite]).to eq(["invite_already_exists"])
      end
    end

    context "when user already exists" do
      let(:args) do
        {
          current_organization: organization,
          email: user.email,
          roles: %w[admin]
        }
      end

      it "returns false and result has errors" do
        expect(validate_service).not_to be_valid
        expect(result.error.messages[:email]).to eq(["email_already_used"])
      end
    end

    context "when roles is invalid" do
      let(:args) do
        {
          current_organization: organization,
          email: Faker::Internet.email,
          roles: %w[super_admin]
        }
      end

      it "returns false and result has errors" do
        expect(validate_service).not_to be_valid
        expect(result.error.messages[:roles]).to eq(%w[invalid_role])
      end
    end
  end
end
