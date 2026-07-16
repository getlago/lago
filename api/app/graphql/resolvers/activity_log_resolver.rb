# frozen_string_literal: true

module Resolvers
  class ActivityLogResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "audit_logs:view"

    description "Query a single activity log of an organization"

    argument :activity_id, ID, required: true, description: "Uniq ID of the activity log"

    type Types::ActivityLogs::Object, null: true

    def resolve(activity_id: nil)
      raise unauthorized_error unless License.premium?
      raise forbidden_error(code: "feature_unavailable") unless Utils::ActivityLog.available?

      current_organization.activity_logs.find_by!(activity_id: activity_id)
    rescue ActiveRecord::RecordNotFound
      not_found_error(resource: "activity_log")
    end
  end
end
