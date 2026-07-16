# frozen_string_literal: true

module Api
  module V1
    module DataApi
      class UsagesController < Api::V1::DataApi::BaseController
        def index
          @result = ::DataApi::UsagesService.call(current_organization, **filter_params)

          if @result.success?
            render_result(@result)
          else
            render_error_response(@result)
          end
        end

        private

        def render_result(result)
          render(json: {"usages" => result.usages}.to_json)
        end

        def filter_params
          params.permit(
            :time_granularity,
            :currency,
            :from_date,
            :to_date,
            :customer_type,
            :external_customer_id,
            :customer_country,
            :external_subscription_id,
            :is_billable_metric_recurring,
            :plan_code,
            :billable_metric_code
          ).to_h.compact
        end
      end
    end
  end
end
