# frozen_string_literal: true

module Api
  module V1
    module Customers
      class CreditNotesController < BaseController
        include CreditNoteIndex

        def index
          credit_note_index(external_customer_id: customer.external_id)
        end

        private

        def resource_name
          "credit_note"
        end
      end
    end
  end
end
