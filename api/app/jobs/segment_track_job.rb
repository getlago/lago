# frozen_string_literal: true

class SegmentTrackJob < ApplicationJob
  queue_as :default

  def perform(membership_id:, event:, properties:)
    return if ENV["LAGO_DISABLE_SEGMENT"] == "true"

    SEGMENT_CLIENT.track(
      user_id: membership_id || "membership/unidentifiable",
      event:,
      properties: properties.merge(hosting_type, version)
    )
  end

  private

  def hosting_type
    {hosting_type: (ENV["LAGO_CLOUD"] == "true") ? "cloud" : "self"}
  end

  def version
    {version: LAGO_VERSION.number}
  end
end
