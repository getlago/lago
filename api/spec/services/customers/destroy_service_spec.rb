# frozen_string_literal: true

require "rails_helper"

RSpec.describe Customers::DestroyService do
  subject(:destroy_service) { described_class.new(customer:) }

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }

  before do
    customer
  end

  describe "#call" do
    it "soft deletes the customer" do
      freeze_time do
        expect { destroy_service.call }.to change(Customer, :count).by(-1)
          .and change { customer.reload.deleted_at }.from(nil).to(Time.current)
      end
    end

    it "enqueues a job to terminates the customer resources" do
      destroy_service.call

      expect(Customers::TerminateRelationsJob).to have_been_enqueued
        .with(customer_id: customer.id)
    end

    it "produces an activity log" do
      described_class.call(customer:)

      expect(Utils::ActivityLog).to have_produced("customer.deleted").after_commit.with(customer)
    end

    context "when customer is not found" do
      let(:customer) { nil }

      it "returns an error" do
        result = destroy_service.call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("customer_not_found")
      end
    end
  end
end
