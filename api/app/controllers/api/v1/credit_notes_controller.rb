# frozen_string_literal: true

module Api
  module V1
    class CreditNotesController < Api::BaseController
      include CreditNoteIndex

      def create
        result = ::CreditNotes::CreateService.call(
          invoice: current_organization.invoices.visible.find_by(id: input_params[:invoice_id]),
          **input_params
        )

        if result.success?
          render(
            json: ::V1::CreditNoteSerializer.new(
              result.credit_note,
              root_name: "credit_note",
              includes: include_in_serializer
            )
          )
        else
          render_error_response(result)
        end
      end

      def show
        credit_note = current_organization.credit_notes.finalized.find_by(id: params[:id])
        return not_found_error(resource: "credit_note") unless credit_note

        render(
          json: ::V1::CreditNoteSerializer.new(
            credit_note,
            root_name: "credit_note",
            includes: include_in_serializer
          )
        )
      end

      def update
        credit_note = current_organization.credit_notes.find_by(id: params[:id])
        return not_found_error(resource: "credit_note") unless credit_note

        result = ::CreditNotes::UpdateService.new(credit_note:, partial_metadata: true, **update_params).call

        if result.success?
          render(
            json: ::V1::CreditNoteSerializer.new(
              result.credit_note,
              root_name: "credit_note",
              includes: include_in_serializer
            )
          )
        else
          render_error_response(result)
        end
      end

      def download_pdf
        credit_note = current_organization.credit_notes.finalized.find_by(id: params[:id])
        return not_found_error(resource: "credit_note") unless credit_note

        if credit_note.file.present?
          return render(
            json: ::V1::CreditNoteSerializer.new(
              credit_note,
              root_name: "credit_note"
            )
          )
        end

        ::CreditNotes::GeneratePdfJob.perform_later(credit_note)

        head(:ok)
      end

      def download_xml
        credit_note = current_organization.credit_notes.finalized.find_by(id: params[:id])
        return not_found_error(resource: "credit_note") unless credit_note

        if credit_note.file.present?
          return render(
            json: ::V1::CreditNoteSerializer.new(
              credit_note,
              root_name: "credit_note"
            )
          )
        end

        ::CreditNotes::GenerateXmlJob.perform_later(credit_note)

        head(:ok)
      end

      def void
        credit_note = current_organization.credit_notes.find_by(id: params[:id])
        return not_found_error(resource: "credit_note") unless credit_note

        result = ::CreditNotes::VoidService.new(credit_note:).call

        if result.success?
          render(
            json: ::V1::CreditNoteSerializer.new(
              credit_note,
              root_name: "credit_note",
              includes: include_in_serializer
            )
          )
        else
          render_error_response(result)
        end
      end

      def index
        permitted_params = params.permit(:external_customer_id)
        external_customer_id = permitted_params[:external_customer_id]

        credit_note_index(external_customer_id:)
      end

      def resend_email
        credit_note = current_organization.credit_notes.finalized.find_by(id: params[:id])
        return not_found_error(resource: "credit_note") unless credit_note

        result = Emails::ResendService.call(
          resource: credit_note,
          to: resend_email_params[:to],
          cc: resend_email_params[:cc],
          bcc: resend_email_params[:bcc]
        )

        if result.success?
          head(:ok)
        else
          render_error_response(result)
        end
      end

      def estimate
        result = ::CreditNotes::EstimateService.call(
          invoice: current_organization.invoices.visible.find_by(id: estimate_params[:invoice_id]),
          items: estimate_params[:items]
        )

        if result.success?
          render(
            json: ::V1::CreditNotes::EstimateSerializer.new(
              result.credit_note,
              root_name: "estimated_credit_note"
            )
          )
        else
          render_error_response(result)
        end
      end

      private

      def include_in_serializer
        [:items, :applied_taxes, :error_details, {customer: [:integration_customers]}]
      end

      def input_params
        @input_params ||= params.require(:credit_note)
          .permit(
            :invoice_id,
            :reason,
            :description,
            :credit_amount_cents,
            :refund_amount_cents,
            :offset_amount_cents,
            metadata: {},
            items: [
              :fee_id,
              :amount_cents
            ]
          )
      end

      def update_params
        params.require(:credit_note).permit(:refund_status, metadata: {})
      end

      def estimate_params
        @estimate_params ||= params.require(:credit_note)
          .permit(
            :invoice_id,
            items: [
              :fee_id,
              :amount_cents
            ]
          )
      end

      def resend_email_params
        params.permit(to: [], cc: [], bcc: [])
      end

      def resource_name
        "credit_note"
      end
    end
  end
end
