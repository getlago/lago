# frozen_string_literal: true

module AddOns
  class UpdateService < BaseService
    Result = BaseResult[:add_on]

    def initialize(add_on:, params:)
      @add_on = add_on
      @params = params
      super
    end

    def call
      return result.not_found_failure!(resource: "add_on") unless add_on

      add_on.name = params[:name] if params.key?(:name)
      add_on.invoice_display_name = params[:invoice_display_name] if params.key?(:invoice_display_name)
      add_on.description = params[:description] if params.key?(:description)
      add_on.code = params[:code] if params.key?(:code)
      add_on.amount_cents = params[:amount_cents] if params.key?(:amount_cents)
      add_on.amount_currency = params[:amount_currency] if params.key?(:amount_currency)

      ActiveRecord::Base.transaction do
        add_on.save!

        if params.key?(:tax_codes)
          taxes_result = AddOns::ApplyTaxesService.call(add_on:, tax_codes: params[:tax_codes])
          taxes_result.raise_if_error!
        end
      end

      result.add_on = add_on
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue BaseService::FailedResult => e
      e.result
    end

    private

    attr_reader :add_on, :params
  end
end
