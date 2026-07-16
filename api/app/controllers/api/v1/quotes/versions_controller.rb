# frozen_string_literal: true

module Api
  module V1
    module Quotes
      class VersionsController < Api::BaseController
        before_action :ensure_feature_flag!
        before_action :find_quote

        def index
          versions = @quote.versions
            .page(params[:page])
            .per(params[:per_page] || PER_PAGE)

          render(
            json: ::CollectionSerializer.new(
              versions,
              ::V1::QuoteVersionSerializer,
              collection_name: "quote_versions",
              meta: pagination_metadata(versions)
            )
          )
        end

        private

        def ensure_feature_flag!
          forbidden_error(code: "feature_unavailable") unless current_organization.feature_flag_enabled?(:order_forms)
        end

        def find_quote
          @quote = current_organization.quotes.find_by(id: params[:quote_id])
          not_found_error(resource: "quote") unless @quote
        end

        def resource_name
          "quote"
        end
      end
    end
  end
end
