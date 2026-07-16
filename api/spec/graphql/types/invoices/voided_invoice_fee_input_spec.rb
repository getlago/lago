# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Invoices::VoidedInvoiceFeeInput do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:add_on_id).of_type("ID")
    expect(subject).to accept_argument(:charge_filter_id).of_type("ID")
    expect(subject).to accept_argument(:charge_id).of_type("ID")
    expect(subject).to accept_argument(:fixed_charge_id).of_type("ID")
    expect(subject).to accept_argument(:description).of_type("String")
    expect(subject).to accept_argument(:id).of_type("ID")
    expect(subject).to accept_argument(:invoice_display_name).of_type("String")
    expect(subject).to accept_argument(:subscription_id).of_type("ID")
    expect(subject).to accept_argument(:unit_amount_cents).of_type("BigInt")
    expect(subject).to accept_argument(:units).of_type("Float")
  end
end
