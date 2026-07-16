# frozen_string_literal: true

module Api
  module V1
    module Analytics
      class BaseController < Api::BaseController
        def index
          if @result.success?
            render_result(@result)
          else
            render_error_response(@result)
          end
        end

        private

        def render_result(result)
          render(
            json: ::CollectionSerializer.new(
              result.records,
              "::V1::Analytics::#{controller_name.classify}Serializer".constantize,
              collection_name: controller_name
            )
          )
        end

        def resource_name
          "analytic"
        end

        def billing_entity
          @billing_entity ||= BillingEntity.find_by(organization_id: current_organization.id, code: params[:billing_entity_code])
        end
      end
    end
  end
end
