# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Invoices::RetryPaymentInput do
  subject { described_class }

  it "has the expected arguments with correct types" do
    expect(subject).to accept_argument(:id).of_type("ID!")
    expect(subject).to accept_argument(:payment_method).of_type("PaymentMethodReferenceInput")
  end
end
