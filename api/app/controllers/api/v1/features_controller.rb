# frozen_string_literal: true

module Api
  module V1
    class FeaturesController < Api::BaseController
      def index
        result = ::Entitlement::FeaturesQuery.call(
          organization: current_organization,
          pagination: {
            page: params[:page],
            limit: params[:per_page] || PER_PAGE
          },
          search_term: params[:search_term]
        )

        if result.success?
          render(
            json: ::CollectionSerializer.new(
              result.features.includes(:privileges),
              ::V1::Entitlement::FeatureSerializer,
              collection_name: "features",
              meta: pagination_metadata(result.features)
            )
          )
        else
          render_error_response(result)
        end
      end

      def create
        result = ::Entitlement::FeatureCreateService.call(
          organization: current_organization,
          params: feature_create_params
        )

        if result.success?
          render(
            json: ::V1::Entitlement::FeatureSerializer.new(
              result.feature,
              root_name:
            )
          )
        else
          render_error_response(result)
        end
      end

      def show
        feature = current_organization.features.where(code: params[:code]).first

        return not_found_error(resource: "feature") unless feature

        render(
          json: ::V1::Entitlement::FeatureSerializer.new(
            feature,
            root_name:
          )
        )
      end

      def update
        feature = current_organization.features.where(code: params[:code]).first
        return not_found_error(resource: "feature") unless feature

        result = ::Entitlement::FeatureUpdateService.call(
          feature:,
          params: feature_update_params,
          partial: true
        )

        if result.success?
          render(
            json: ::V1::Entitlement::FeatureSerializer.new(
              result.feature,
              root_name:
            )
          )
        else
          render_error_response(result)
        end
      end

      def destroy
        feature = current_organization.features.where(code: params[:code]).first
        result = ::Entitlement::FeatureDestroyService.call(feature:)

        if result.success?
          render(
            json: ::V1::Entitlement::FeatureSerializer.new(
              result.feature,
              root_name:
            )
          )
        else
          render_error_response(result)
        end
      end

      private

      def feature_create_params
        params.require(:feature).permit(:code, :name, :description, privileges: [
          :code, :name, :value_type, config: {}
        ])
      end

      def feature_update_params
        params.require(:feature).permit(:name, :description, privileges: [
          :code, :name, :value_type, config: {}
        ])
      end

      def root_name
        "feature"
      end

      def resource_name
        "feature"
      end
    end
  end
end
