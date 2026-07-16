# frozen_string_literal: true

module V1
  class PaymentRequestSerializer < ModelSerializer
    def serialize
      payload = {
        lago_id: model.id,
        amount_cents: model.amount_cents,
        amount_currency: model.amount_currency,
        email: model.email,
        payment_status: model.payment_status,
        created_at: model.created_at.iso8601
      }

      payload.merge!(customer) if include?(:customer)
      payload.merge!(invoices) if include?(:invoices)

      payload
    end

    private

    def customer
      {
        customer: ::V1::CustomerSerializer.new(model.customer).serialize
      }
    end

    def invoices
      ::CollectionSerializer.new(
        model.invoices,
        ::V1::InvoiceSerializer,
        collection_name: "invoices"
      ).serialize
    end
  end
end
