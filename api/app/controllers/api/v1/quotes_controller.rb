# frozen_string_literal: true

module Api
  module V1
    class QuotesController < Api::BaseController
      before_action :ensure_feature_flag!

      def index
        result = QuotesQuery.call(
          organization: current_organization,
          pagination: {
            page: params[:page],
            limit: params[:per_page] || PER_PAGE
          },
          filters: index_filters
        )

        if result.success?
          quotes = result.quotes.includes(:current_version)
          render_quotes(quotes, meta: pagination_metadata(result.quotes))
        else
          render_error_response(result)
        end
      end

      def show
        quote = current_organization.quotes.find_by(id: params[:id])
        return not_found_error(resource: "quote") unless quote

        render_quote(quote)
      end

      private

      def ensure_feature_flag!
        forbidden_error(code: "feature_unavailable") unless current_organization.feature_flag_enabled?(:order_forms)
      end

      def index_filters
        {
          statuses: Array.wrap(params[:status]).presence,
          order_types: Array.wrap(params[:order_type]).presence,
          numbers: Array.wrap(params[:number]).presence,
          owners: Array.wrap(params[:owner_id]).presence,
          external_customer_ids: Array.wrap(params[:external_customer_id]).presence,
          from_date: params[:from_date],
          to_date: params[:to_date]
        }
      end

      def render_quotes(quotes, meta:)
        render(
          json: ::CollectionSerializer.new(
            quotes,
            ::V1::QuoteSerializer,
            collection_name: "quotes",
            meta:
          )
        )
      end

      def render_quote(quote)
        render(json: ::V1::QuoteSerializer.new(quote, root_name: "quote", includes: %i[owners]))
      end

      def resource_name
        "quote"
      end
    end
  end
end
