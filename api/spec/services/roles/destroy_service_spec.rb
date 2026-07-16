# frozen_string_literal: true

require "rails_helper"

RSpec.describe Roles::DestroyService do
  include_context "with mocked security logger"

  describe "#call" do
    subject(:result) { described_class.call(role:) }

    let(:organization) { create(:organization) }
    let(:role) { create(:role, organization:) }

    context "when role exists and has no assigned members" do
      it "soft-deletes the role" do
        expect { result }.to change { role.reload.deleted_at }.from(nil)
      end

      it "returns success" do
        expect(result).to be_success
        expect(result.role).to eq(role)
      end

      it_behaves_like "produces a security log", "role.deleted" do
        before { result }
      end
    end

    context "when role is nil" do
      let(:role) { nil }

      it "returns not found error" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.error_code).to eq("role_not_found")
      end

      it_behaves_like "does not produce a security log" do
        before { result }
      end
    end

    context "when role is predefined" do
      let(:role) { create(:role, :predefined, name: "Finance") }

      it "does not delete the role" do
        expect { result }.not_to change { role.reload.deleted_at }
      end

      it "returns forbidden error" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
        expect(result.error.code).to eq("predefined_role")
      end

      it_behaves_like "does not produce a security log" do
        before { result }
      end
    end

    context "when role has assigned members" do
      let(:membership) { create(:membership, organization:) }

      before { create(:membership_role, membership:, role:) }

      it "does not delete the role" do
        expect { result }.not_to change { role.reload.deleted_at }
      end

      it "returns forbidden error" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
        expect(result.error.code).to eq("role_assigned_to_members")
      end

      it_behaves_like "does not produce a security log" do
        before { result }
      end
    end

    context "when role is assigned only to revoked memberships" do
      let(:membership) { create(:membership, :revoked, organization:) }

      before { create(:membership_role, membership:, role:) }

      it "soft-deletes the role" do
        expect(result).to be_success
        expect(role.reload.deleted_at).to be_present
      end
    end
  end
end
