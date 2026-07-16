# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Subscriptions::TerminateSubscriptionInput do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:id).of_type("ID!")
    expect(subject).to accept_argument(:on_termination_credit_note).of_type("OnTerminationCreditNoteEnum")
    expect(subject).to accept_argument(:on_termination_invoice).of_type("OnTerminationInvoiceEnum")
  end
end
