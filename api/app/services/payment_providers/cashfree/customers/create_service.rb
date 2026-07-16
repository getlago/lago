# frozen_string_literal: true

module PaymentProviders
  module Cashfree
    module Customers
      class CreateService < BaseService
        def initialize(customer:, payment_provider_id:, params:, async: true)
          @customer = customer
          @payment_provider_id = payment_provider_id
          @params = params || {}
          @async = async

          super
        end

        def call
          provider_customer = PaymentProviderCustomers::CashfreeCustomer.find_by(customer_id: customer.id)
          provider_customer ||= PaymentProviderCustomers::CashfreeCustomer.new(
            customer_id: customer.id,
            payment_provider_id:,
            organization_id: organization.id
          )

          if params.key?(:sync_with_provider)
            provider_customer.sync_with_provider = params[:sync_with_provider].presence
          end

          provider_customer.save!

          result.provider_customer = provider_customer

          result
        rescue ActiveRecord::RecordInvalid => e
          result.record_validation_failure!(record: e.record)
        end

        private

        attr_accessor :customer, :payment_provider_id, :params, :async

        delegate :organization, to: :customer
      end
    end
  end
end
