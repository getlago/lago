# frozen_string_literal: true

require "rails_helper"

RSpec.describe Memberships::UpdateService do
  include_context "with mocked security logger"

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:acting_user) { create(:membership, organization:).user }
  let(:admin_role) { create(:role, :admin) }
  let!(:manager_role) { create(:role, :manager) }
  let(:params) { {roles: %w[manager]} }

  describe "#call" do
    context "when another admin exists" do
      before do
        create(:membership_role, membership:, role: admin_role)
        other_membership = create(:membership, organization:)
        create(:membership_role, membership: other_membership, role: admin_role)
      end

      it "updates the role" do
        result = described_class.call(user: acting_user, membership:, params:)

        expect(result).to be_success
        expect(result.membership.roles).to eq([manager_role])
      end

      it_behaves_like "produces a security log", "user.role_edited" do
        before { described_class.call(user: acting_user, membership:, params:) }
      end
    end

    context "when admin grants admin role to another member" do
      let(:acting_membership) { create(:membership, organization:) }
      let(:acting_user) { acting_membership.user }
      let(:params) { {roles: %w[admin]} }

      before do
        create(:membership_role, membership: acting_membership, role: admin_role)
        create(:membership_role, membership:, role: manager_role)
      end

      it "updates the role" do
        result = described_class.call(user: acting_user, membership:, params:)

        expect(result).to be_success
        expect(result.membership.roles).to eq([admin_role])
      end

      it_behaves_like "produces a security log", "user.role_edited" do
        before { described_class.call(user: acting_user, membership:, params:) }
      end
    end

    context "when non-admin grants admin role to another member" do
      let(:params) { {roles: %w[admin]} }

      before do
        admin_role
        create(:membership_role, membership:, role: manager_role)
      end

      it "returns an error" do
        result = described_class.call(user: acting_user, membership:, params:)

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
        expect(result.error.code).to eq("cannot_grant_admin")
      end

      it_behaves_like "does not produce a security log" do
        before { described_class.call(user: acting_user, membership:, params:) }
      end
    end

    context "when membership is the last admin" do
      before { create(:membership_role, membership:, role: admin_role) }

      it "returns an error" do
        result = described_class.call(user: acting_user, membership:, params:)

        expect(result).not_to be_success
        expect(result.error.code).to eq("last_admin")
      end

      it_behaves_like "does not produce a security log" do
        before { described_class.call(user: acting_user, membership:, params:) }
      end
    end

    context "when membership is not found" do
      it "returns an error" do
        result = described_class.call(user: acting_user, membership: nil, params:)

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("membership_not_found")
      end

      it_behaves_like "does not produce a security log" do
        before { described_class.call(user: acting_user, membership: nil, params:) }
      end
    end

    context "when role is invalid" do
      before { create(:membership_role, membership:, role: admin_role) }

      let(:params) { {roles: %w[invalid]} }

      it "returns an error" do
        result = described_class.call(user: acting_user, membership:, params:)

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("role_not_found")
      end

      it_behaves_like "does not produce a security log" do
        before { described_class.call(user: acting_user, membership:, params:) }
      end
    end
  end
end
