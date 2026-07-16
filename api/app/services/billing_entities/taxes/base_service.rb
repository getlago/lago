# frozen_string_literal: true

module BillingEntities
  module Taxes
    class BaseService < BaseService
      private

      attr_reader :billing_entity

      def refresh_draft_invoices
        BillingEntities::Taxes::RefreshDraftInvoicesJob.perform_later(billing_entity.id)
      end
    end
  end
end
