# frozen_string_literal: true

module Api
  module V1
    module Customers
      class ProjectedUsageController < Api::BaseController
        def current
          apply_taxes = ActiveModel::Type::Boolean.new.cast(params.fetch(:apply_taxes, true))
          result = ::Invoices::CustomerUsageService
            .with_external_ids(
              customer_external_id: params[:customer_external_id],
              external_subscription_id: params[:external_subscription_id],
              organization_id: current_organization.id,
              apply_taxes:,
              calculate_projected_usage: true
            ).call

          if result.success?
            render(
              json: ::V1::Customers::ProjectedUsageSerializer.new(
                result.usage,
                root_name: "customer_projected_usage"
              )
            )
          else
            render_error_response(result)
          end
        end

        private

        def resource_name
          "customer_usage"
        end

        def authorize
          super

          return if current_organization.projected_usage_enabled?

          forbidden_error(code: "projected_usage_not_enabled")
        end
      end
    end
  end
end
