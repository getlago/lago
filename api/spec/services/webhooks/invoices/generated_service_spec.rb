# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::Invoices::GeneratedService do
  subject(:webhook_service) { described_class.new(object: invoice) }

  let(:customer) { create(:customer, organization:) }
  let(:subscription) { create(:subscription, organization:, customer:) }
  let(:invoice) { create(:invoice, customer:, organization:) }
  let(:organization) { create(:organization) }

  describe ".call" do
    it_behaves_like "creates webhook", "invoice.generated", "invoice", {"fees_amount_cents" => Integer}
  end
end
