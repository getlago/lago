# frozen_string_literal: true

module Api
  module V1
    class ActivityLogsController < Api::BaseController
      include PremiumFeatureOnly

      skip_audit_logs!

      def index
        result = ActivityLogsQuery.call(
          organization: current_organization,
          pagination: {
            page: params[:page],
            limit: params[:per_page] || PER_PAGE
          },
          filters: index_filters
        )

        if result.success?
          render(
            json: ::CollectionSerializer.new(
              result.activity_logs,
              ::V1::ActivityLogSerializer,
              collection_name: "activity_logs",
              meta: pagination_metadata(result.activity_logs)
            )
          )
        else
          render_error_response(result)
        end
      end

      def show
        activity_log = current_organization.activity_logs.find_by(
          activity_id: params[:activity_id]
        )

        return not_found_error(resource: "activity_log") unless activity_log

        render(
          json: ::V1::ActivityLogSerializer.new(
            activity_log,
            root_name: "activity_log"
          )
        )
      end

      private

      def resource_name
        "activity_log"
      end

      def index_filters
        {
          from_date: params[:from_date],
          to_date: params[:to_date],
          activity_types: params[:activity_types],
          activity_sources: params[:activity_sources],
          user_emails: params[:user_emails],
          external_customer_id: params[:external_customer_id],
          external_subscription_id: params[:external_subscription_id],
          resource_ids: params[:resource_ids],
          resource_types: params[:resource_types]
        }
      end
    end
  end
end
