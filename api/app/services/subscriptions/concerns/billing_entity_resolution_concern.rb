# frozen_string_literal: true

module Subscriptions
  module Concerns
    module BillingEntityResolutionConcern
      extend ActiveSupport::Concern

      private

      def resolve_billing_entity(organization:, params:)
        return unless organization.feature_flag_enabled?(:multi_entity_billing)

        if params[:billing_entity_id].present?
          organization.billing_entities.find(params[:billing_entity_id])
        elsif params[:billing_entity_code].present?
          organization.billing_entities.find_by!(code: params[:billing_entity_code])
        end
      rescue ActiveRecord::RecordNotFound
        result.not_found_failure!(resource: "billing_entity").raise_if_error!
      end
    end
  end
end
