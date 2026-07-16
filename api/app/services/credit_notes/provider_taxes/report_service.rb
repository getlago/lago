# frozen_string_literal: true

module CreditNotes
  module ProviderTaxes
    class ReportService < BaseService
      Result = BaseResult[:credit_note]

      def initialize(credit_note:)
        @credit_note = credit_note

        super
      end

      def call
        return result.not_found_failure!(resource: "credit_note") unless credit_note

        credit_note.error_details.tax_error.discard_all # rubocop:disable Lago/DiscardAll

        tax_result = Integrations::Aggregator::Taxes::CreditNotes::CreateService.new(credit_note:).call

        unless tax_result.success?
          create_error_detail(tax_result.error.code)

          return result.validation_failure!(errors: {tax_error: [tax_result.error.code]})
        end

        result.credit_note = credit_note

        result
      end

      private

      attr_reader :credit_note

      delegate :customer, to: :credit_note

      def create_error_detail(code)
        error_result = ErrorDetails::CreateService.call(
          owner: credit_note,
          organization: credit_note.organization,
          params: {
            error_code: :tax_error,
            details: {
              tax_error: code
            }
          }
        )
        error_result.raise_if_error!
      end
    end
  end
end
