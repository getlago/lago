# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::DataExports::Invoices::FiltersInput do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:amount_from).of_type("Int")
    expect(subject).to accept_argument(:amount_to).of_type("Int")
    expect(subject).to accept_argument(:billing_entity_ids).of_type("[ID!]")
    expect(subject).to accept_argument(:currency).of_type("CurrencyEnum")
    expect(subject).to accept_argument(:customer_external_id).of_type("String")
    expect(subject).to accept_argument(:invoice_type).of_type("[InvoiceTypeEnum!]")
    expect(subject).to accept_argument(:issuing_date_from).of_type("ISO8601Date")
    expect(subject).to accept_argument(:issuing_date_to).of_type("ISO8601Date")
    expect(subject).to accept_argument(:payment_dispute_lost).of_type("Boolean")
    expect(subject).to accept_argument(:payment_overdue).of_type("Boolean")
    expect(subject).to accept_argument(:payment_status).of_type("[InvoicePaymentStatusTypeEnum!]")
    expect(subject).to accept_argument(:search_term).of_type("String")
    expect(subject).to accept_argument(:status).of_type("[InvoiceStatusTypeEnum!]")
  end
end
