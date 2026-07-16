# frozen_string_literal: true

module Mutations
  module BillableMetrics
    class Create < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "billable_metrics:create"

      graphql_name "CreateBillableMetric"
      description "Creates a new Billable metric"

      input_object_class Types::BillableMetrics::CreateInput

      type Types::BillableMetrics::Object

      def resolve(**args)
        result = ::BillableMetrics::CreateService
          .call(**args.merge(organization_id: current_organization.id))

        result.success? ? result.billable_metric : result_error(result)
      end
    end
  end
end
