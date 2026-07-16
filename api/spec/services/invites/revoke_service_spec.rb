# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invites::RevokeService do
  subject(:revoke_service) { described_class.new(invite) }

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:invite) { create(:invite, organization:) }

  describe "#call" do
    it "revokes the invite" do
      freeze_time do
        result = revoke_service.call

        expect(result).to be_success
        expect(result.invite.id).to eq(invite.id)
        expect(result.invite).to be_revoked
        expect(result.invite.revoked_at).to eq(Time.current)
      end
    end

    context "when invite is not found" do
      let(:invite) { nil }

      it "returns an error" do
        result = revoke_service.call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("invite_not_found")
      end
    end

    context "when invite is revoked" do
      let(:invite) { create(:invite, organization:, status: "revoked") }

      it "returns an error" do
        result = revoke_service.call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("invite_not_found")
      end
    end

    context "when invite is accepted" do
      let(:invite) { create(:invite, organization:, status: "accepted") }

      it "returns an error" do
        result = revoke_service.call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("invite_not_found")
      end
    end
  end
end
