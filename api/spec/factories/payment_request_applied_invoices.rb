# frozen_string_literal: true

FactoryBot.define do
  factory :payment_request_applied_invoice, class: "PaymentRequest::AppliedInvoice" do
    payment_request
    invoice
    organization { invoice&.organization || payment_request&.organization || association(:organization) }
  end
end
