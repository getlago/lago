# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Integrations::SyncHubspotInvoiceInput do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:invoice_id).of_type("ID!")
  end
end
