# frozen_string_literal: true

module Api
  module V1
    class OrdersController < Api::BaseController
      before_action :ensure_feature_flag!

      def index
        result = OrdersQuery.call(
          organization: current_organization,
          pagination: {
            page: params[:page],
            limit: params[:per_page] || PER_PAGE
          },
          filters: index_filters,
          search_term: params[:search_term]
        )

        if result.success?
          render(
            json: ::CollectionSerializer.new(
              result.orders,
              ::V1::OrderSerializer,
              collection_name: "orders",
              meta: pagination_metadata(result.orders)
            )
          )
        else
          render_error_response(result)
        end
      end

      def show
        order = current_organization.orders.find_by(id: params[:id])
        return not_found_error(resource: "order") unless order

        render_order(order)
      end

      private

      def ensure_feature_flag!
        forbidden_error(code: "feature_unavailable") unless current_organization.feature_flag_enabled?(:order_forms)
      end

      def index_filters
        {
          status: params[:status],
          order_type: params[:order_type],
          execution_mode: params[:execution_mode],
          customer_id: params[:customer_id],
          number: params[:number],
          order_form_number: params[:order_form_number],
          quote_number: params[:quote_number],
          owner_id: params[:owner_id],
          executed_at_from: params[:executed_at_from],
          executed_at_to: params[:executed_at_to]
        }
      end

      def render_order(order)
        render(
          json: ::V1::OrderSerializer.new(order, root_name: "order")
        )
      end

      def resource_name
        "order"
      end
    end
  end
end
