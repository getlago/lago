# frozen_string_literal: true

require "rails_helper"

RSpec.describe Memberships::RevokeService do
  subject(:revoke_service) { described_class.new(user:, membership:) }

  include_context "with mocked security logger"

  let(:organization) { create(:organization) }
  let(:admin_role) { create(:role, :admin) }
  let(:finance_role) { create(:role, :finance) }

  let(:user) { create(:user) }
  let(:membership) { create(:membership, organization:) }
  let(:other_membership) { create(:membership, user:, organization:) }

  describe "#call" do
    context "when revoking my own membership" do
      let(:membership) { create(:membership, user:, organization:) }
      let(:other_membership) { create(:membership, organization:) }

      before { create(:membership_role, membership: other_membership, role: admin_role) }

      it "returns an error" do
        result = revoke_service.call

        expect(result).not_to be_success
        expect(result.error.code).to eq("cannot_revoke_own_membership")
      end

      it_behaves_like "does not produce a security log" do
        before { revoke_service.call }
      end
    end

    context "when membership is not found" do
      let(:membership) { nil }

      it "returns an error" do
        result = revoke_service.call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("membership_not_found")
      end

      it_behaves_like "does not produce a security log" do
        before { revoke_service.call }
      end
    end

    context "when revoking another membership" do
      before { create(:membership_role, membership: other_membership, role: admin_role) }

      it "revokes the membership" do
        freeze_time do
          result = revoke_service.call

          expect(result).to be_success
          expect(result.membership.id).to eq(membership.id)
          expect(result.membership.status).to eq("revoked")
          expect(result.membership.revoked_at).to eq(Time.current)
        end
      end

      it_behaves_like "produces a security log", "user.deleted" do
        before { revoke_service.call }
      end
    end

    context "when removing the last admin" do
      before do
        create(:membership_role, membership:, role: admin_role)
        create(:membership_role, membership: other_membership, role: finance_role)
      end

      it "returns an error" do
        result = revoke_service.call

        expect(result).not_to be_success
        expect(result.error.code).to eq("last_admin")
      end

      it_behaves_like "does not produce a security log" do
        before { revoke_service.call }
      end
    end

    context "when removing the last active admin (other admins have revoked membership)" do
      let(:revoked_membership) { create(:membership, :revoked, organization:) }

      before do
        create(:membership_role, membership:, role: admin_role)
        create(:membership_role, membership: other_membership, role: finance_role)
        create(:membership_role, membership: revoked_membership, role: admin_role)
      end

      it "returns an error" do
        result = revoke_service.call

        expect(result).not_to be_success
        expect(result.error.code).to eq("last_admin")
      end

      it_behaves_like "does not produce a security log" do
        before { revoke_service.call }
      end
    end
  end
end
