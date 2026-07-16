# frozen_string_literal: true

module Commitments
  class OverrideService < BaseService
    Result = BaseResult[:commitment]

    def initialize(commitment:, params:)
      @commitment = commitment
      @params = params

      super
    end

    def call
      return result if !License.premium? || !commitment

      ActiveRecord::Base.transaction do
        new_commitment = commitment.dup.tap do |c|
          c.amount_cents = params[:amount_cents] if params.key?(:amount_cents)
          c.invoice_display_name = params[:invoice_display_name] if params.key?(:invoice_display_name)
          c.plan_id = params[:plan_id]
        end

        new_commitment.save!

        if params.key?(:tax_codes)
          taxes_result = Commitments::ApplyTaxesService.call(commitment: new_commitment, tax_codes: params[:tax_codes])
          taxes_result.raise_if_error!
        end

        result.commitment = new_commitment
      end

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :commitment, :params
  end
end
