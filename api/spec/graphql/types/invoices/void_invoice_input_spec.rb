# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Invoices::VoidInvoiceInput do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:id).of_type("ID!")
    expect(subject).to accept_argument(:generate_credit_note).of_type("Boolean")
    expect(subject).to accept_argument(:credit_amount).of_type("BigInt")
    expect(subject).to accept_argument(:refund_amount).of_type("BigInt")
  end
end
