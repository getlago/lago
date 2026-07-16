# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::Invoices::OneOffCreatedService do
  subject(:webhook_service) { described_class.new(object: invoice) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:invoice) { create(:invoice, customer:, organization:) }

  describe ".call" do
    it_behaves_like "creates webhook", "invoice.one_off_created", "invoice"
  end
end
