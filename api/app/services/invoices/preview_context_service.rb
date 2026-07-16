# frozen_string_literal: true

module Invoices
  class PreviewContextService < BaseService
    Result = BaseResult[:customer, :subscriptions, :applied_coupons]

    def initialize(organization:, billing_entity:, params:)
      @organization = organization
      @billing_entity = billing_entity
      @params = params.presence || {}
      super
    end

    def call
      result.customer = find_or_build_customer
      result.applied_coupons = find_or_build_applied_coupons

      subscriptions_service = ::Invoices::Preview::SubscriptionsService.call(
        organization: organization,
        customer: result.customer,
        params: subscription_params,
        billing_entity: billing_entity
      )

      if subscriptions_service.success?
        result.subscriptions = subscriptions_service.subscriptions
      else
        result.fail_with_error!(subscriptions_service.error)
      end

      result
    rescue ActiveRecord::RecordNotFound => exception
      result.not_found_failure!(resource: exception.model.demodulize.underscore)
      result
    end

    private

    attr_reader :params, :organization, :billing_entity

    def subscription_params
      params.slice(:billing_time, :plan_code, :subscription_at, :subscriptions)
    end

    def new_customer_billing_entity
      if organization.feature_flag_enabled?(:multi_entity_billing)
        organization.default_billing_entity
      else
        billing_entity
      end
    end

    def find_or_build_customer
      customer_params = params[:customer] || {}

      customer = if customer_params.key?(:external_id)
        organization.customers.find_by!(external_id: customer_params[:external_id])
      else
        organization.customers.new(
          created_at: Time.current,
          updated_at: Time.current,
          billing_entity: new_customer_billing_entity
        )
      end

      customer.assign_attributes(
        **customer_params.slice(
          :name,
          :tax_identification_number,
          :currency,
          :timezone,
          :address_line1,
          :address_line2,
          :city,
          :zipcode,
          :state,
          :country
        ),
        shipping_address_line1: customer_params.dig(:shipping_address, :address_line1),
        shipping_address_line2: customer_params.dig(:shipping_address, :address_line2),
        shipping_city: customer_params.dig(:shipping_address, :city),
        shipping_zipcode: customer_params.dig(:shipping_address, :zipcode),
        shipping_state: customer_params.dig(:shipping_address, :state),
        shipping_country: customer_params.dig(:shipping_address, :country)
      )

      Array(customer_params[:integration_customers]).map do |integration_params|
        build_customer_integration(customer, integration_params)
      end

      customer
    end

    def build_customer_integration(customer, attrs)
      integration_class = integration_type(attrs[:integration_type]).constantize
      integration = integration_class.find_by!(code: attrs[:integration_code], organization:)
      type = IntegrationCustomers::BaseCustomer.customer_type(attrs[:integration_type]).constantize

      customer.integration_customers.build(integration:, type:)
    end

    def find_or_build_applied_coupons
      applied_coupons = result.customer
        .applied_coupons.active
        .joins(:coupon)
        .order("coupons.limited_billable_metrics DESC, coupons.limited_plans DESC, applied_coupons.created_at ASC")
        .presence

      applied_coupons || Array(params[:coupons]).map do |coupon_attr|
        coupon = coupon_attr.key?(:code) && organization.coupons.find_by(code: coupon_attr[:code])
        coupon || Coupon.new(coupon_attr)
      end.map do |coupon|
        AppliedCoupon.new(
          id: SecureRandom.uuid,
          coupon:,
          customer: result.customer,
          organization:,
          amount_cents: coupon.amount_cents,
          amount_currency: coupon.amount_currency,
          percentage_rate: coupon.percentage_rate,
          frequency: coupon.frequency,
          frequency_duration: coupon.frequency_duration,
          frequency_duration_remaining: coupon.frequency_duration
        )
      end
    end

    def integration_type(type)
      case type
      when "anrok"
        "Integrations::AnrokIntegration"
      when "avalara"
        "Integrations::AvalaraIntegration"
      when "xero"
        "Integrations::XeroIntegration"
      when "hubspot"
        "Integrations::HubspotIntegration"
      when "salesforce"
        "Integrations::SalesforceIntegration"
      else
        raise(NotImplementedError)
      end
    end
  end
end
