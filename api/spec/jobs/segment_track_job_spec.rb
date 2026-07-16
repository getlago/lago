# frozen_string_literal: true

require "rails_helper"

describe SegmentTrackJob, job: true do
  subject { described_class }

  describe ".perform" do
    let(:membership_id) { "membership/#{SecureRandom.uuid}" }
    let(:event) { "event" }
    let(:properties) do
      {method: 1}
    end

    before do
      ENV["LAGO_DISABLE_SEGMENT"] = ""
      allow(CurrentContext).to receive(:membership).and_return(membership_id)
      allow(SEGMENT_CLIENT).to receive(:track)
    end

    it "calls SegmentTrackJob's process method" do
      subject.perform_now(membership_id:, event:, properties:)

      expect(SEGMENT_CLIENT).to have_received(:track)
        .with(
          user_id: membership_id,
          event:,
          properties: {
            method: 1,
            hosting_type: "self",
            version: "test"
          }
        )
    end

    context "when LAGO_CLOUD is true" do
      it "includes hosting type equal to cloud" do
        ENV["LAGO_CLOUD"] = "true"

        subject.perform_now(membership_id:, event:, properties:)

        expect(SEGMENT_CLIENT).to have_received(:track).with(
          hash_including(properties: hash_including(hosting_type: "cloud"))
        )
      end
    end

    context "when membership is nil" do
      it "sends event to an unidentifiable membership" do
        subject.perform_now(membership_id: nil, event:, properties:)

        expect(SEGMENT_CLIENT).to have_received(:track).with(
          hash_including(user_id: "membership/unidentifiable")
        )
      end
    end

    context "when LAGO_DISABLE_SEGMENT is true" do
      it "does not call SegmentTrackJob" do
        ENV["LAGO_DISABLE_SEGMENT"] = "true"

        subject.perform_now(membership_id:, event:, properties:)

        expect(SEGMENT_CLIENT).not_to have_received(:track)
      end
    end
  end
end
