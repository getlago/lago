# frozen_string_literal: true

module Resolvers
  class ApiLogResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "audit_logs:view"

    description "Query a single api log of an organization"

    argument :request_id, ID, required: true, description: "Uniq ID of the api log"

    type Types::ApiLogs::Object, null: true

    def resolve(request_id: nil)
      raise unauthorized_error unless License.premium?
      raise forbidden_error(code: "feature_unavailable") unless Utils::ApiLog.available?

      current_organization.api_logs.find_by!(request_id:)
    rescue ActiveRecord::RecordNotFound
      not_found_error(resource: "api_log")
    end
  end
end
