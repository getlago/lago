# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::ApplyInvoiceCustomSectionsService do
  subject(:invoice_service) { described_class.new(invoice:, resources:, custom_section_ids:) }

  let(:organization) { create(:organization) }
  let(:billing_entity) { create(:billing_entity, organization:) }
  let(:customer) { create(:customer, organization:, billing_entity:) }
  let(:invoice) { create(:invoice, customer:, billing_entity:) }
  let(:custom_section_1) { create(:invoice_custom_section, organization:) }
  let(:custom_section_2) { create(:invoice_custom_section, organization:) }
  let(:custom_section_3) { create(:invoice_custom_section, organization:) }
  let(:resources) { [] }
  let(:custom_section_ids) { [] }

  before do
    create(:billing_entity_applied_invoice_custom_section, organization:, billing_entity:, invoice_custom_section: custom_section_1)
    create(:billing_entity_applied_invoice_custom_section, organization:, billing_entity:, invoice_custom_section: custom_section_2)
  end

  describe "#call" do
    context "when the customer has skip_invoice_custom_sections flag" do
      let(:customer) { create(:customer, organization:, billing_entity:, skip_invoice_custom_sections: true) }

      it "does not apply any custom sections" do
        result = invoice_service.call
        expect(result).to be_success
        expect(result.applied_sections).to be_empty
        expect(invoice.reload.applied_invoice_custom_sections).to be_empty
      end
    end

    context "when the customer belongs to a different billing entity" do
      let(:customer) { create(:customer, organization:, billing_entity: create(:billing_entity, organization:)) }

      it "does not apply any custom sections" do
        result = invoice_service.call
        expect(result).to be_success
        expect(result.applied_sections).to be_empty
        expect(invoice.reload.applied_invoice_custom_sections).to be_empty
      end
    end

    context "when the customer has custom sections" do
      before do
        create(:customer_applied_invoice_custom_section, organization:, billing_entity:, customer:, invoice_custom_section: custom_section_3)
      end

      it "applies the custom sections to the invoice" do
        result = invoice_service.call
        expect(result).to be_success
        sections = invoice.applied_invoice_custom_sections.reload
        expect(sections.map(&:code)).to contain_exactly(custom_section_3.code)
        expect(sections.map(&:details)).to contain_exactly(custom_section_3.details)
        expect(sections.map(&:display_name)).to contain_exactly(custom_section_3.display_name)
        expect(sections.map(&:name)).to contain_exactly(custom_section_3.name)
      end
    end

    context "when the customer inherits custom sections from the organization" do
      it "applies the organization's sections to the invoice" do
        result = invoice_service.call
        expect(result).to be_success
        sections = invoice.applied_invoice_custom_sections.reload
        expect(sections.map(&:code)).to contain_exactly(custom_section_1.code, custom_section_2.code)
        expect(sections.map(&:details)).to contain_exactly(custom_section_1.details, custom_section_2.details)
        expect(sections.map(&:display_name)).to contain_exactly(custom_section_1.display_name, custom_section_2.display_name)
        expect(sections.map(&:name)).to contain_exactly(custom_section_1.name, custom_section_2.name)
      end
    end

    context "with a single resource" do
      let(:subscription) { create(:subscription, customer:, organization:) }
      let(:resources) { [subscription] }

      context "when skip_invoice_custom_sections is true" do
        let(:subscription) { create(:subscription, customer:, organization:, skip_invoice_custom_sections: true) }

        it "does not attach custom sections on the invoice" do
          result = invoice_service.call
          expect(result).to be_success
          expect(result.applied_sections).to be_empty
          expect(invoice.reload.applied_invoice_custom_sections).to be_empty
        end
      end

      context "when skip_invoice_custom_sections is false but there is no attached custom sections" do
        context "with customer sections" do
          before do
            create(:customer_applied_invoice_custom_section, organization:, billing_entity:, customer:, invoice_custom_section: custom_section_3)
          end

          it "applies the customer sections on the invoice" do
            result = invoice_service.call
            expect(result).to be_success
            sections = invoice.applied_invoice_custom_sections.reload
            expect(sections.map(&:code)).to contain_exactly(custom_section_3.code)
            expect(sections.map(&:details)).to contain_exactly(custom_section_3.details)
            expect(sections.map(&:display_name)).to contain_exactly(custom_section_3.display_name)
            expect(sections.map(&:name)).to contain_exactly(custom_section_3.name)
          end
        end

        context "when there is no customer sections" do
          it "applies the organization sections on the invoice" do
            result = invoice_service.call
            expect(result).to be_success
            sections = invoice.applied_invoice_custom_sections.reload
            expect(sections.map(&:code)).to contain_exactly(custom_section_1.code, custom_section_2.code)
            expect(sections.map(&:details)).to contain_exactly(custom_section_1.details, custom_section_2.details)
            expect(sections.map(&:display_name)).to contain_exactly(custom_section_1.display_name, custom_section_2.display_name)
            expect(sections.map(&:name)).to contain_exactly(custom_section_1.name, custom_section_2.name)
          end
        end
      end

      context "when skip_invoice_custom_sections is false and there are attached custom sections" do
        before do
          create(:subscription_applied_invoice_custom_section, organization:, subscription:, invoice_custom_section: custom_section_2)
        end

        it "applies custom sections from the subscription" do
          result = invoice_service.call
          expect(result).to be_success
          sections = invoice.applied_invoice_custom_sections.reload
          expect(sections.map(&:code)).to contain_exactly(custom_section_2.code)
          expect(sections.map(&:details)).to contain_exactly(custom_section_2.details)
          expect(sections.map(&:display_name)).to contain_exactly(custom_section_2.display_name)
          expect(sections.map(&:name)).to contain_exactly(custom_section_2.name)
        end
      end
    end

    context "with multiple resources" do
      let(:subscription_a) { create(:subscription, customer:, organization:) }
      let(:subscription_b) { create(:subscription, customer:, organization:) }
      let(:resources) { [subscription_a, subscription_b] }

      context "when no resource has ICS" do
        it "falls back to customer sections" do
          result = invoice_service.call
          expect(result).to be_success
          sections = invoice.applied_invoice_custom_sections.reload
          expect(sections.map(&:code)).to contain_exactly(custom_section_1.code, custom_section_2.code)
        end
      end

      context "when all resources have ICS" do
        before do
          create(:subscription_applied_invoice_custom_section, organization:, subscription: subscription_a, invoice_custom_section: custom_section_1)
          create(:subscription_applied_invoice_custom_section, organization:, subscription: subscription_b, invoice_custom_section: custom_section_2)
        end

        it "merges ICS from all resources" do
          result = invoice_service.call
          expect(result).to be_success
          sections = invoice.applied_invoice_custom_sections.reload
          expect(sections.map(&:code)).to contain_exactly(custom_section_1.code, custom_section_2.code)
        end
      end

      context "when some resources have ICS and some do not" do
        before do
          create(:subscription_applied_invoice_custom_section, organization:, subscription: subscription_a, invoice_custom_section: custom_section_1)
          create(:customer_applied_invoice_custom_section, organization:, billing_entity:, customer:, invoice_custom_section: custom_section_3)
        end

        it "merges resource ICS with customer sections" do
          result = invoice_service.call
          expect(result).to be_success
          sections = invoice.applied_invoice_custom_sections.reload
          expect(sections.map(&:code)).to contain_exactly(custom_section_1.code, custom_section_3.code)
        end
      end

      context "when all resources have skip_invoice_custom_sections" do
        let(:subscription_a) { create(:subscription, customer:, organization:, skip_invoice_custom_sections: true) }
        let(:subscription_b) { create(:subscription, customer:, organization:, skip_invoice_custom_sections: true) }

        it "does not apply any custom sections" do
          result = invoice_service.call
          expect(result).to be_success
          expect(result.applied_sections).to be_empty
          expect(invoice.reload.applied_invoice_custom_sections).to be_empty
        end
      end

      context "when one resource skips and another has ICS" do
        let(:subscription_a) { create(:subscription, customer:, organization:, skip_invoice_custom_sections: true) }

        before do
          create(:subscription_applied_invoice_custom_section, organization:, subscription: subscription_b, invoice_custom_section: custom_section_2)
        end

        it "applies only the non-skipping resource's ICS" do
          result = invoice_service.call
          expect(result).to be_success
          sections = invoice.applied_invoice_custom_sections.reload
          expect(sections.map(&:code)).to contain_exactly(custom_section_2.code)
        end
      end
    end

    context "with custom section ids provided" do
      let(:custom_section_ids) { [custom_section_4.id] }
      let(:custom_section_4) { create(:invoice_custom_section, organization:) }

      it "applies the given sections on the invoice" do
        result = invoice_service.call
        expect(result).to be_success
        sections = invoice.applied_invoice_custom_sections.reload
        expect(sections.map(&:code)).to contain_exactly(custom_section_4.code)
        expect(sections.map(&:details)).to contain_exactly(custom_section_4.details)
        expect(sections.map(&:display_name)).to contain_exactly(custom_section_4.display_name)
        expect(sections.map(&:name)).to contain_exactly(custom_section_4.name)
      end
    end
  end
end
