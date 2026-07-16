# frozen_string_literal: true

require "rails_helper"

describe SegmentIdentifyJob, job: true do
  subject { described_class }

  describe ".perform" do
    let(:membership_id) { "membership/#{membership.id}" }
    let(:membership) { create(:membership) }

    before do
      ENV["LAGO_DISABLE_SEGMENT"] = ""
      allow(CurrentContext).to receive(:membership).and_return(membership_id)
      allow(SEGMENT_CLIENT).to receive(:identify)
    end

    it "calls SegmentIdentifyJob's process method" do
      subject.perform_now(membership_id:)

      expect(SEGMENT_CLIENT).to have_received(:identify)
        .with(
          user_id: membership_id,
          traits: {
            created_at: membership.created_at,
            hosting_type: "self",
            version: "test",
            organization_name: membership.organization.name,
            email: membership.user.email
          }
        )
    end

    context "when LAGO_CLOUD is true" do
      before do
        ENV["LAGO_CLOUD"] = "true"
      end

      it "includes hosting type equal to cloud" do
        subject.perform_now(membership_id:)

        expect(SEGMENT_CLIENT).to have_received(:identify).with(
          hash_including(traits: hash_including(hosting_type: "cloud"))
        )
      end
    end

    context "when membership is nil" do
      it "does not send any events" do
        subject.perform_now(membership_id: nil)

        expect(SEGMENT_CLIENT).not_to have_received(:identify)
      end
    end

    context "when membership is unidentifiable" do
      it "does not send any events" do
        subject.perform_now(membership_id: "membership/unidentifiable")

        expect(SEGMENT_CLIENT).not_to have_received(:identify)
      end
    end

    context "when LAGO_DISABLE_SEGMENT is true" do
      it "does not call SegmentIdentifyJob" do
        ENV["LAGO_DISABLE_SEGMENT"] = "true"

        subject.perform_now(membership_id:)
        expect(SEGMENT_CLIENT).not_to have_received(:identify)
      end
    end
  end
end
