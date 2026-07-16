# frozen_string_literal: true

module Api
  module V1
    module CreditNotes
      class BaseController < Api::BaseController
        before_action :find_credit_note

        private

        attr_reader :credit_note

        def find_credit_note
          @credit_note = current_organization.credit_notes.finalized.find_by!(id: params[:credit_note_id])
        rescue ActiveRecord::RecordNotFound
          not_found_error(resource: "credit_note")
        end

        def resource_name
          "credit_note"
        end
      end
    end
  end
end
