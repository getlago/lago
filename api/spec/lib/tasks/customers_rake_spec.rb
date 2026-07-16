# frozen_string_literal: true

require "rails_helper"

require "rake"

RSpec.describe "customers:backfill_eu_auto_taxes" do # rubocop:disable RSpec/DescribeClass
  let(:task) { Rake::Task["customers:backfill_eu_auto_taxes"] }

  let(:organization) { create(:organization) }
  let(:billing_entity) { create(:billing_entity, organization:, country: "FR", eu_tax_management: true) }

  let(:fr_standard) { create(:tax, organization:, code: "lago_eu_fr_standard") }

  before do
    Rake.application.rake_require("tasks/customers")
    Rake::Task.define_task(:environment)
    task.reenable
    create(:tax, organization:, code: "lago_eu_de_standard")
  end

  def apply_tax(customer, tax)
    create(:customer_applied_tax, customer:, tax:)
  end

  context "without an organization_id argument" do
    it "aborts with a usage message" do
      expect { task.invoke }.to raise_error(SystemExit).and output(/Missing organization_id argument/).to_stderr
    end
  end

  context "when DRY_RUN is disabled" do
    around do |example|
      ENV["DRY_RUN"] = "false"
      example.run
    ensure
      ENV["DRY_RUN"] = nil
    end

    context "when customer country differs from currently applied EU standard tax" do
      let(:customer) do
        create(:customer, organization:, billing_entity:, country: "DE", zipcode: "10115", tax_identification_number: nil)
      end

      before { apply_tax(customer, fr_standard) }

      it "re-applies the customer country standard tax" do
        task.invoke(organization.id)

        expect(customer.reload.taxes.pluck(:code)).to contain_exactly("lago_eu_de_standard")
      end

      context "when the customer also has a manually applied non-EU tax" do
        let!(:custom_tax) { create(:tax, organization:, code: "custom_local_tax") }

        before { apply_tax(customer, custom_tax) }

        it "preserves the manually applied non-EU tax" do
          task.invoke(organization.id)

          expect(customer.reload.taxes.pluck(:code)).to match_array(["lago_eu_de_standard", "custom_local_tax"])
        end
      end
    end

    context "when customer country matches the currently applied EU standard tax" do
      let(:customer) { create(:customer, organization:, billing_entity:, country: "FR") }

      before { apply_tax(customer, fr_standard) }

      it "does not change the applied tax" do
        expect { task.invoke(organization.id) }.not_to change { customer.reload.taxes.pluck(:code) }
      end
    end

    context "when billing entity has eu_tax_management disabled" do
      let(:billing_entity) { create(:billing_entity, organization:, country: "FR", eu_tax_management: false) }
      let(:customer) { create(:customer, organization:, billing_entity:, country: "DE") }

      before { apply_tax(customer, fr_standard) }

      it "does not process the customer" do
        expect { task.invoke(organization.id) }.not_to change { customer.reload.taxes.pluck(:code) }
      end
    end

    context "when customer has no country" do
      let(:customer) { create(:customer, organization:, billing_entity:, country: nil) }

      before { apply_tax(customer, fr_standard) }

      it "does not process the customer" do
        expect { task.invoke(organization.id) }.not_to change { customer.reload.taxes.pluck(:code) }
      end
    end

    context "when customer is on a reverse charge tax" do
      let!(:reverse_charge) { create(:tax, organization:, code: "lago_eu_reverse_charge") }
      let(:customer) { create(:customer, organization:, billing_entity:, country: "DE") }

      before { apply_tax(customer, reverse_charge) }

      it "does not process the customer" do
        expect { task.invoke(organization.id) }.not_to change { customer.reload.taxes.pluck(:code) }
      end
    end

    context "when customer is on an exception tax code" do
      let!(:exception_tax) { create(:tax, organization:, code: "lago_eu_fr_exception_corsica") }
      let(:customer) { create(:customer, organization:, billing_entity:, country: "FR", zipcode: "20000") }

      before { apply_tax(customer, exception_tax) }

      it "does not process the customer" do
        expect { task.invoke(organization.id) }.not_to change { customer.reload.taxes.pluck(:code) }
      end
    end

    context "when customer already has a pending VIES check" do
      let(:customer) do
        create(:customer, organization:, billing_entity:, country: "DE", tax_identification_number: "DE123456789")
      end

      before do
        apply_tax(customer, fr_standard)
        create(:pending_vies_check, customer:)
      end

      it "does not process the customer" do
        expect { task.invoke(organization.id) }.not_to change { customer.reload.taxes.pluck(:code) }
      end
    end

    context "when customer has a tax identification number but no pending VIES check" do
      let(:customer) do
        create(:customer, organization:, billing_entity:, country: "DE", tax_identification_number: "DE123456789")
      end

      before { apply_tax(customer, fr_standard) }

      it "schedules an async VIES check and leaves the tax unchanged for now" do
        expect { task.invoke(organization.id) }.to change(PendingViesCheck, :count).by(1)
        expect(customer.reload.taxes.pluck(:code)).to contain_exactly("lago_eu_fr_standard")
      end
    end

    context "when BATCH_SIZE is smaller than the number of matching customers" do
      before do
        ENV["BATCH_SIZE"] = "1"

        2.times do
          customer = create(:customer, organization:, billing_entity:, country: "DE", tax_identification_number: nil)
          apply_tax(customer, fr_standard)
        end
      end

      after { ENV.delete("BATCH_SIZE") }

      it "processes all customers across multiple batches" do
        task.invoke(organization.id)

        expect(Customer.where(organization:).flat_map { |c| c.taxes.pluck(:code) }.uniq)
          .to contain_exactly("lago_eu_de_standard")
      end
    end

    context "when the affected customer belongs to another organization" do
      let(:other_organization) { create(:organization) }
      let(:other_billing_entity) do
        create(:billing_entity, organization: other_organization, country: "FR", eu_tax_management: true)
      end
      let(:other_customer) do
        create(:customer, organization: other_organization, billing_entity: other_billing_entity, country: "DE", tax_identification_number: nil)
      end
      let(:other_fr_standard) { create(:tax, organization: other_organization, code: "lago_eu_fr_standard") }

      before do
        create(:tax, organization: other_organization, code: "lago_eu_de_standard")
        apply_tax(other_customer, other_fr_standard)
      end

      it "does not process the customer" do
        expect { task.invoke(organization.id) }.not_to change { other_customer.reload.taxes.pluck(:code) }
      end
    end
  end

  context "when DRY_RUN is enabled" do
    around do |example|
      ENV["DRY_RUN"] = "true"
      example.run
    ensure
      ENV["DRY_RUN"] = nil
    end

    context "when customer country differs from currently applied EU standard tax" do
      let(:customer) do
        create(:customer, organization:, billing_entity:, country: "DE", zipcode: "10115", tax_identification_number: nil)
      end

      before { apply_tax(customer, fr_standard) }

      it "does not change the applied taxes" do
        expect { task.invoke(organization.id) }.not_to change { customer.reload.taxes.pluck(:code) }
      end

      it "does not enqueue a ViesCheckJob" do
        expect { task.invoke(organization.id) }.not_to have_enqueued_job(Customers::ViesCheckJob)
      end

      it "prints a dry-run preview with the target tax code" do
        expect { task.invoke(organization.id) }
          .to output(/\[DRY RUN\].*target=lago_eu_de_standard.*would re-apply/).to_stdout
      end
    end

    context "when customer has a tax identification number" do
      let(:customer) do
        create(:customer, organization:, billing_entity:, country: "DE", tax_identification_number: "DE123456789")
      end

      before { apply_tax(customer, fr_standard) }

      it "does not create a PendingViesCheck record" do
        expect { task.invoke(organization.id) }.not_to change(PendingViesCheck, :count)
      end

      it "does not enqueue a ViesCheckJob" do
        expect { task.invoke(organization.id) }.not_to have_enqueued_job(Customers::ViesCheckJob)
      end

      it "prints a dry-run preview indicating a VIES check would be scheduled" do
        expect { task.invoke(organization.id) }
          .to output(/\[DRY RUN\].*would schedule VIES check/).to_stdout
      end
    end

    context "when there are no matching candidates" do
      let(:customer) { create(:customer, organization:, billing_entity:, country: "FR") }

      before { apply_tax(customer, fr_standard) }

      it "prints the DRY RUN header and summary" do
        expect { task.invoke(organization.id) }
          .to output(/Starting EU auto-taxes backfill \[DRY RUN\].*Done \[DRY RUN\]/m).to_stdout
      end
    end
  end

  context "when DRY_RUN is not set" do
    around do |example|
      ENV.delete("DRY_RUN")
      example.run
    end

    let(:customer) do
      create(:customer, organization:, billing_entity:, country: "DE", zipcode: "10115", tax_identification_number: nil)
    end

    before { apply_tax(customer, fr_standard) }

    it "defaults to dry-run mode and does not change applied taxes" do
      expect { task.invoke(organization.id) }.not_to change { customer.reload.taxes.pluck(:code) }
    end

    it "prints a DRY RUN preview" do
      expect { task.invoke(organization.id) }
        .to output(/Starting EU auto-taxes backfill \[DRY RUN\]/).to_stdout
    end
  end
end
