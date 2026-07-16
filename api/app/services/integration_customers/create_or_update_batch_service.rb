# frozen_string_literal: true

module IntegrationCustomers
  class CreateOrUpdateBatchService < ::BaseService
    SYNC_INTEGRATIONS = ["Integrations::SalesforceIntegration"].freeze
    def initialize(integration_customers:, customer:, new_customer:)
      @integration_customers = integration_customers&.map { |c| c.to_h.deep_symbolize_keys }
      @customer = customer
      @new_customer = new_customer

      super(nil)
    end

    def call
      return if integration_customers.nil? || customer.nil?
      return if customer.partner_account?

      sanitize_integration_customers

      integration_customers.each do |int_customer_params|
        @integration_customer_params = int_customer_params

        next unless integration
        next if skip_creating_integration_customer?

        if create_integration_customer?
          handle_creation
        elsif update_integration_customer?
          handle_update
        end
      end
    end

    private

    attr_reader :integration_customer_params, :customer, :new_customer, :integration_customers

    def create_integration_customer?
      (new_customer && integration_customer_params[:sync_with_provider]) ||
        (new_customer && integration_customer_params[:external_customer_id]) ||
        (!new_customer && integration_customer.nil? && integration_customer_params[:sync_with_provider]) ||
        (!new_customer && integration_customer.nil? && integration_customer_params[:external_customer_id])
    end

    def update_integration_customer?
      !new_customer && integration_customer
    end

    def handle_creation
      # salesforce don't need to reach a provider so it can be done sync
      if SYNC_INTEGRATIONS.include? integration&.type
        IntegrationCustomers::CreateJob.perform_now(
          integration_customer_params: integration_customer_params,
          integration:,
          customer:
        )
      else
        IntegrationCustomers::CreateJob.perform_later(
          integration_customer_params: integration_customer_params,
          integration:,
          customer:
        )
      end
    end

    def handle_update
      if SYNC_INTEGRATIONS.include? integration&.type
        IntegrationCustomers::UpdateJob.perform_now(
          integration_customer_params: integration_customer_params,
          integration:,
          integration_customer:
        )
      else
        IntegrationCustomers::UpdateJob.perform_later(
          integration_customer_params: integration_customer_params,
          integration:,
          integration_customer:
        )
      end
    end

    def sanitize_integration_customers
      updated_int_customers = integration_customers.reject { |m| m[:id].nil? }.map { |m| m[:id] }
      not_needed_ids = customer.integration_customers.pluck(:id) - updated_int_customers

      customer.integration_customers.where(id: not_needed_ids).destroy_all
    end

    def skip_creating_integration_customer?
      integration_customer.nil? &&
        integration_customer_params[:sync_with_provider].blank? &&
        integration_customer_params[:external_customer_id].blank?
    end

    def integration
      type = Integrations::BaseIntegration.integration_type(integration_customer_params[:integration_type])

      return @integration if defined?(@integration) && @integration&.type == type

      return nil unless integration_customer_params &&
        integration_customer_params[:integration_type] &&
        integration_customer_params[:integration_code]

      code = integration_customer_params[:integration_code]

      @integration = Integrations::BaseIntegration.find_by(type:, code:, organization: customer.organization)
    end

    def integration_customer
      type = IntegrationCustomers::BaseCustomer.customer_type(integration_customer_params[:integration_type])

      return @integration_customer if defined?(@integration_customer) && @integration_customer&.type == type

      @integration_customer = IntegrationCustomers::BaseCustomer.find_by(integration:, customer:)
    end
  end
end
