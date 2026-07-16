# frozen_string_literal: true

module Organizations
  class CreateService < BaseService
    Result = BaseResult[:organization]

    def initialize(params)
      @params = params
      super
    end

    def call
      organization = Organization.new(
        params.slice(:name, :document_numbering, :premium_integrations)
      )

      if ActiveModel::Type::Boolean.new.cast(ENV["LAGO_CLICKHOUSE_ENABLED"]) && ENV["LAGO_DEFAULT_EVENT_STORE"] == "clickhouse"
        organization.clickhouse_events_store = true
        organization.clickhouse_deduplication_enabled = true
      end

      ActiveRecord::Base.transaction do
        # TODO: remove when we do not support document_numbering per organization
        organization.save!
        organization.api_keys.create!
        if params[:document_numbering]
          params[:document_numbering] = "per_billing_entity" if params[:document_numbering] == "per_organization"
        end

        # NOTE: ensure first billing entity has the same id as the organization to ease the migration to multi entities.
        params[:id] = organization.id

        params[:code] = params[:name]&.parameterize(separator: "_") if params[:code].blank?
        BillingEntities::CreateService.call(organization: organization, params: params)
      end

      result.organization = organization
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :params
  end
end
