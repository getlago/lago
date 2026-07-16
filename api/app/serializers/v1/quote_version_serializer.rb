# frozen_string_literal: true

module V1
  class QuoteVersionSerializer < ModelSerializer
    def serialize
      payload = {
        lago_id: model.id,
        lago_quote_id: model.quote_id,
        lago_organization_id: model.organization_id,
        version: model.version,
        status: model.status,
        currency: model.currency,
        start_date: model.start_date&.iso8601,
        end_date: model.end_date&.iso8601,
        void_reason: model.void_reason,
        approved_at: model.approved_at&.iso8601,
        voided_at: model.voided_at&.iso8601,
        created_at: model.created_at.iso8601,
        updated_at: model.updated_at.iso8601
      }

      # content/billing_items are heavy blobs: render them only for single-resource
      # responses, never in list/embed payloads.
      payload[:content] = model.content if include?(:content)
      payload[:billing_items] = model.billing_items if include?(:billing_items)

      # share_token is intentionally omitted from the REST API. It is a bearer capability
      # with no consumer yet; it should be disclosed only through a purpose-built share
      # endpoint when the sharing feature lands, not as an ambient read field.
      payload
    end
  end
end
