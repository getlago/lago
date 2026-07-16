# frozen_string_literal: true

module Api
  module V1
    class QuoteVersionsController < Api::BaseController
      before_action :ensure_feature_flag!

      def show
        quote_version = current_organization.quote_versions.find_by(id: params[:id])
        return not_found_error(resource: "quote_version") unless quote_version

        render_quote_version(quote_version)
      end

      def approve
        # A nil quote_version is intentional: the service returns a not_found failure.
        quote_version = current_organization.quote_versions.find_by(id: params[:id])

        result = QuoteVersions::ApproveService.call(quote_version:, expires_at: params[:expires_at])

        if result.success?
          render_quote_version(result.quote_version)
        else
          render_error_response(result)
        end
      end

      def void
        # A nil quote_version is intentional: the service returns a not_found failure.
        quote_version = current_organization.quote_versions.find_by(id: params[:id])

        result = QuoteVersions::VoidService.call(quote_version:, reason: :manual)

        if result.success?
          render_quote_version(result.quote_version)
        else
          render_error_response(result)
        end
      end

      def clone
        # A nil quote_version is intentional: the service returns a not_found failure.
        quote_version = current_organization.quote_versions.find_by(id: params[:id])

        result = QuoteVersions::CloneService.call(quote_version:)

        if result.success?
          render_quote_version(result.quote_version)
        else
          render_error_response(result)
        end
      end

      private

      def ensure_feature_flag!
        forbidden_error(code: "feature_unavailable") unless current_organization.feature_flag_enabled?(:order_forms)
      end

      def render_quote_version(quote_version)
        render(json: ::V1::QuoteVersionSerializer.new(quote_version, root_name: "quote_version", includes: %i[content billing_items]))
      end

      # API-key scope bucket: ApiKey::RESOURCES has "quote" but no "quote_version",
      # so quote versions authorize against the "quote" scope. This is intentionally
      # distinct from the not_found_error "quote_version" resource label.
      def resource_name
        "quote"
      end
    end
  end
end
