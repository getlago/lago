# frozen_string_literal: true

require "rails_helper"

RSpec.describe DatabaseMigrations::FixInvoicesOrganizationSequentialIdJob do
  subject(:perform_job) { described_class.perform_now }

  let(:organization) { create(:organization, document_numbering: :per_organization) }

  context "when maximum sequential_id matches invoice count" do
    it "does not change the last invoice" do
      invoice_1 = create(:invoice, organization:, organization_sequential_id: 1)
      invoice_2 = create(:invoice, organization:, organization_sequential_id: 2)

      expect { perform_job }
        .to not_change { invoice_1.reload.organization_sequential_id }
        .and not_change { invoice_2.reload.organization_sequential_id }
    end
  end

  context "when maximum sequential_id does not match invoice count" do
    it "updates the last invoice sequential_id" do
      invoice_1 = create(:invoice, organization:, organization_sequential_id: 1, created_at: 2.days.ago)
      invoice_2 = create(:invoice, organization:, organization_sequential_id: 0, created_at: 1.day.ago)

      expect { perform_job }
        .to change { invoice_2.reload.organization_sequential_id }.to(2)
        .and not_change { invoice_1.reload.organization_sequential_id }
    end

    it "does not consider self-billed invoices" do
      invoice_1 = create(:invoice, organization:, organization_sequential_id: 0, created_at: 2.days.ago)
      invoice_2 = create(:invoice, :self_billed, organization:, organization_sequential_id: 0, created_at: 1.day.ago)

      expect { perform_job }
        .to change { invoice_1.reload.organization_sequential_id }.to(1)
        .and not_change { invoice_2.reload.organization_sequential_id }
    end

    it "does not consider draft invoices" do
      invoice_1 = create(:invoice, organization:, organization_sequential_id: 0, created_at: 2.days.ago)
      invoice_2 = create(:invoice, :draft, organization:, organization_sequential_id: 0, created_at: 1.day.ago)

      expect { perform_job }
        .to change { invoice_1.reload.organization_sequential_id }.to(1)
        .and not_change { invoice_2.reload.organization_sequential_id }
    end
  end

  context "when organization has no invoices" do
    it "does nothing" do
      expect { perform_job }.not_to raise_error
    end
  end

  context "when organization is on per_customer document_numbering" do
    let(:organization) { create(:organization, document_numbering: :per_customer) }

    it "does not change any invoices" do
      invoice = create(:invoice, organization:, organization_sequential_id: 0)

      expect { perform_job }
        .not_to change { invoice.reload.organization_sequential_id }
    end
  end
end
