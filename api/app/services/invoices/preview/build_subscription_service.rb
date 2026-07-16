# frozen_string_literal: true

module Invoices
  module Preview
    class BuildSubscriptionService < BaseService
      Result = BaseResult[:subscriptions]

      def initialize(customer:, params:, billing_entity: nil)
        @customer = customer
        @params = params.presence || {}
        @billing_entity = billing_entity
        super
      end

      def call
        return result.not_found_failure!(resource: "customer") unless customer
        return result.not_found_failure!(resource: "plan") unless plan

        result.subscriptions = [build_subscription]
        result
      end

      private

      attr_reader :customer, :params, :billing_entity

      delegate :organization, to: :customer

      def build_subscription
        Subscription.new(
          organization_id: organization.id,
          customer:,
          plan:,
          billing_entity: effective_billing_entity,
          subscription_at: params[:subscription_at].presence || Time.current,
          started_at: params[:subscription_at].presence || Time.current,
          billing_time:,
          created_at: params[:subscription_at].presence || Time.current,
          updated_at: Time.current
        )
      end

      def effective_billing_entity
        return nil unless organization.feature_flag_enabled?(:multi_entity_billing)
        return nil if billing_entity.nil? || billing_entity == customer.billing_entity

        billing_entity
      end

      def billing_time
        if Subscription::BILLING_TIME.include?(params[:billing_time]&.to_sym)
          params[:billing_time]
        else
          "calendar"
        end
      end

      def plan
        @plan ||= organization.plans.parents.find_by(code: params[:plan_code])
      end
    end
  end
end
