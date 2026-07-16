# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::DataExports::CreditNotes::FiltersInput do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:amount_from).of_type("Int")
    expect(subject).to accept_argument(:amount_to).of_type("Int")
    expect(subject).to accept_argument(:billing_entity_ids).of_type("[ID!]")
    expect(subject).to accept_argument(:credit_status).of_type("[CreditNoteCreditStatusEnum!]")
    expect(subject).to accept_argument(:currency).of_type("CurrencyEnum")
    expect(subject).to accept_argument(:customer_external_id).of_type("String")
    expect(subject).to accept_argument(:customer_id).of_type("ID")
    expect(subject).to accept_argument(:invoice_number).of_type("String")
    expect(subject).to accept_argument(:issuing_date_from).of_type("ISO8601Date")
    expect(subject).to accept_argument(:issuing_date_to).of_type("ISO8601Date")
    expect(subject).to accept_argument(:reason).of_type("[CreditNoteReasonEnum!]")
    expect(subject).to accept_argument(:refund_status).of_type("[CreditNoteRefundStatusEnum!]")
    expect(subject).to accept_argument(:search_term).of_type("String")
    expect(subject).to accept_argument(:self_billed).of_type("Boolean")
    expect(subject).to accept_argument(:types).of_type("[CreditNoteTypeEnum!]")
  end
end
