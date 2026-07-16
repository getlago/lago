# frozen_string_literal: true

module Webhooks
  module Features
    class UpdatedService < Webhooks::BaseService
      private

      def current_organization
        @current_organization ||= object.organization
      end

      def object_serializer
        ::V1::Entitlement::FeatureSerializer.new(
          object,
          root_name: "feature"
        )
      end

      def webhook_type
        "feature.updated"
      end

      def object_type
        "feature"
      end
    end
  end
end
