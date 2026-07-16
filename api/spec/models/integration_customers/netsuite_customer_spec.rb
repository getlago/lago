# frozen_string_literal: true

require "rails_helper"

RSpec.describe IntegrationCustomers::NetsuiteCustomer do
  subject(:netsuite_customer) { build(:netsuite_customer) }

  describe "#subsidiary_id" do
    let(:subsidiary_id) { Faker::Number.number(digits: 3) }

    it "assigns and retrieve a setting" do
      netsuite_customer.subsidiary_id = subsidiary_id
      expect(netsuite_customer.subsidiary_id).to eq(subsidiary_id)
    end
  end
end
