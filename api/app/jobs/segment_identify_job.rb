# frozen_string_literal: true

class SegmentIdentifyJob < ApplicationJob
  queue_as :default

  def perform(membership_id:)
    return if ENV["LAGO_DISABLE_SEGMENT"] == "true"
    return if membership_id.nil? || membership_id == "membership/unidentifiable"

    membership = Membership.find(membership_id.delete_prefix("membership/"))
    traits = {
      created_at: membership.created_at,
      hosting_type:,
      version:,
      organization_name: membership.organization.name,
      email: membership.user.email
    }

    SEGMENT_CLIENT.identify(user_id: membership_id, traits:)
  end

  private

  def hosting_type
    @hosting_type ||= (ENV["LAGO_CLOUD"] == "true") ? "cloud" : "self"
  end

  def version
    LAGO_VERSION.number
  end
end
