# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invite do
  subject(:invite) { create(:invite) }

  it_behaves_like "paper_trail traceable"

  describe "#mark_as_revoked" do
    it "revokes the invite with a Time" do
      freeze_time do
        expect { invite.mark_as_revoked! }
          .to change { invite.reload.status }.from("pending").to("revoked")
          .and change(invite, :revoked_at).from(nil).to(Time.current)
      end
    end
  end

  describe "#mark_as_accepted" do
    it "accepts the invite with a Time" do
      freeze_time do
        expect { invite.mark_as_accepted! }
          .to change { invite.reload.status }.from("pending").to("accepted")
          .and change(invite, :accepted_at).from(nil).to(Time.current)
      end
    end
  end

  describe "normalizations" do
    it "sanitizes email on assignment" do
      invite = build(:invite, email: " hello@some\u200Bthing\u2013other.com ")
      expect(invite.email).to eq("hello@something-other.com")
    end
  end

  describe "validations" do
    subject(:invite) { build(:invite, organization:) }

    let(:organization) { create(:organization) }
    let!(:role) { create(:role, :custom, organization:) }

    before { create(:role, :admin) }

    it { is_expected.to be_valid }

    context "with wrong email format" do
      before { invite.email = "wrong" }

      it { is_expected.not_to be_valid }
    end

    context "without email" do
      before { invite.email = nil }

      it { is_expected.not_to be_valid }
    end

    context "when roles is empty" do
      before { invite.roles = [] }

      it { is_expected.to be_valid }
    end

    context "when all roles exist in the organization" do
      before { invite.roles = [role.name.swapcase, "Admin"] }

      it { is_expected.to be_valid }
    end
  end
end
