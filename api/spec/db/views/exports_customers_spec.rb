# frozen_string_literal: true

require "rails_helper"

RSpec.describe "exports_customers view" do # rubocop:disable RSpec/DescribeClass
  let(:customer) { create(:customer) }

  def rows_for(id)
    ActiveRecord::Base.connection.select_all(
      "SELECT * FROM exports_customers WHERE lago_id = #{ActiveRecord::Base.connection.quote(id)}"
    ).to_a
  end

  describe "payment_provider_customers join" do
    context "when the customer has a single live provider customer" do
      let(:provider) { create(:gocardless_provider, organization: customer.organization) }

      before do
        create(:gocardless_customer, customer:, payment_provider: provider, provider_customer_id: "gc_live")
      end

      it "emits one row carrying the provider data" do
        rows = rows_for(customer.id)

        expect(rows.size).to eq(1)
        expect(rows.first["provider_customer_id"]).to eq("gc_live")
      end
    end

    context "when the customer has an orphaned provider customer plus a live one" do
      # PaymentProviders::DestroyService nullifies payment_provider_id without
      # soft-deleting, leaving an orphan row (deleted_at IS NULL). Reconnecting a
      # different provider then adds a second live row, so the unfiltered join
      # emitted two rows and broke the BigQuery MERGE.
      let(:provider) { create(:gocardless_provider, organization: customer.organization) }

      before do
        create(:stripe_customer, customer:, payment_provider: nil, provider_customer_id: "stripe_orphan")
        create(:gocardless_customer, customer:, payment_provider: provider, provider_customer_id: "gc_live")
      end

      it "emits a single row and ignores the orphaned provider customer" do
        rows = rows_for(customer.id)

        expect(rows.size).to eq(1)
        expect(rows.first["provider_customer_id"]).to eq("gc_live")
      end
    end

    context "when the customer only has an orphaned provider customer" do
      before do
        create(:stripe_customer, customer:, payment_provider: nil, provider_customer_id: "stripe_orphan")
      end

      it "emits one row with null provider columns" do
        rows = rows_for(customer.id)

        expect(rows.size).to eq(1)
        expect(rows.first["provider_customer_id"]).to be_nil
      end
    end

    context "when the customer has no provider customer" do
      it "emits one row with null provider columns" do
        rows = rows_for(customer.id)

        expect(rows.size).to eq(1)
        expect(rows.first["provider_customer_id"]).to be_nil
      end
    end
  end
end
