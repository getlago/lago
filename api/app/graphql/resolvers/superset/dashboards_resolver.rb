# frozen_string_literal: true

module Resolvers
  module Superset
    class DashboardsResolver < Resolvers::BaseResolver
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "analytics:view"

      graphql_name "SupersetDashboards"
      description "Query all Superset dashboards with embedded configuration and guest tokens"

      type [Types::Superset::Dashboard::Object], null: false

      def resolve
        result = ::Auth::SupersetService.call(
          organization: current_organization,
          user: nil
        )

        return result_error(result) unless result.success?

        result.dashboards
      end
    end
  end
end
