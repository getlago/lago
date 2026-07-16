# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::Customers::CreatedService do
  subject(:webhook_service) { described_class.new(object: customer) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }

  describe ".call" do
    it_behaves_like "creates webhook", "customer.created", "customer"
  end
end
