# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::Customers::ViesCheckService do
  subject(:webhook_service) { described_class.new(object: customer) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }

  describe ".call" do
    it_behaves_like "creates webhook", "customer.vies_check", "customer"
  end
end
