# frozen_string_literal: true

module IntegrationCustomers
  class BaseService < BaseService
    def initialize(params:, integration:)
      @params = params
      @integration = integration

      super
    end

    def call
      result.not_found_failure!(resource: "integration") unless integration
      result
    end

    private

    attr_reader :params, :integration

    def sync_with_provider
      @sync_with_provider ||= ActiveModel::Type::Boolean.new.cast(params[:sync_with_provider])
    end

    def customer_type
      @customer_type ||= IntegrationCustomers::BaseCustomer.customer_type(params[:integration_type])
    end

    def subsidiary_id
      @subsidiary_id ||= params[:subsidiary_id]
    end

    def targeted_object
      @targeted_object ||= params[:targeted_object]
    end

    def external_customer_id
      @external_customer_id ||= params[:external_customer_id]
    end
  end
end
