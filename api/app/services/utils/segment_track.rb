# frozen_string_literal: true

module Utils
  class SegmentTrack
    class << self
      def invoice_created(invoice)
        SegmentTrackJob.perform_later(
          membership_id: CurrentContext.membership,
          event: "invoice_created",
          properties: {
            organization_id: invoice.organization.id,
            invoice_id: invoice.id,
            invoice_type: invoice.invoice_type
          }
        )
      end

      def refund_status_changed(status, credit_note_id, organization_id)
        SegmentTrackJob.perform_later(
          membership_id: CurrentContext.membership,
          event: "refund_status_changed",
          properties: {
            organization_id: organization_id,
            credit_note_id: credit_note_id,
            refund_status: status
          }
        )
      end
    end
  end
end
