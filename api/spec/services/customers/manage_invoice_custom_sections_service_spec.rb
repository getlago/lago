# frozen_string_literal: true

require "rails_helper"

RSpec.describe Customers::ManageInvoiceCustomSectionsService do
  subject(:result) { described_class.call(customer:, section_ids:, skip_invoice_custom_sections:, section_codes:) }

  let(:customer) { create(:customer) }
  let(:organization) { customer.organization }
  let(:billing_entity) { customer.billing_entity }
  let(:invoice_custom_section_1) { create(:invoice_custom_section, organization:) }
  let(:invoice_custom_section_2) { create(:invoice_custom_section, organization:) }
  let(:invoice_custom_section_3) { create(:invoice_custom_section, organization:) }
  let(:skip_invoice_custom_sections) { nil }
  let(:section_ids) { nil }
  let(:section_codes) { nil }

  describe "#call" do
    context "when customer is not found" do
      let(:customer) { nil }

      it "returns not found failure" do
        expect(result).to be_failure
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("customer_not_found")
      end
    end

    context "when sending section_ids and section_codes together" do
      let(:section_ids) { [invoice_custom_section_1.id] }
      let(:section_codes) { [invoice_custom_section_1.code] }

      it "returns a validation failure" do
        expect(result).to be_failure
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.message).to include("section_ids_and_section_codes_sent_together")
      end
    end

    context "when sending section_ids" do
      context "when sending skip_invoice_custom_sections: true AND selected_ids" do
        let(:skip_invoice_custom_sections) { true }
        let(:section_ids) { [1, 2, 3] }

        it "returns a validation failure" do
          expect(result).to be_failure
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.message).to include("skip_sections_and_selected_ids_sent_together")
        end
      end

      context "when updating selected_invoice_custom_sections" do
        context "when section_ids match customer's applicable sections" do
          let(:section_ids) { [invoice_custom_section_1.id] }

          before do
            create(:customer_applied_invoice_custom_section, customer:, organization:, billing_entity:, invoice_custom_section: invoice_custom_section_1)
            create(:billing_entity_applied_invoice_custom_section, organization:, billing_entity:, invoice_custom_section: invoice_custom_section_2)
          end

          it "returns the result without changes" do
            expect(result).to be_success
            expect(customer.applicable_invoice_custom_sections.reload).to contain_exactly(invoice_custom_section_1)
          end
        end

        context "when section_ids match organization's selected sections" do
          let(:section_ids) { [invoice_custom_section_2.id] }

          before do
            create(:customer_applied_invoice_custom_section, customer:, organization:, billing_entity:, invoice_custom_section: invoice_custom_section_1)
            create(:billing_entity_applied_invoice_custom_section, organization:, billing_entity:, invoice_custom_section: invoice_custom_section_2)
          end

          it "still sets selected invoice_custom_sections as custom" do
            expect(result).to be_success
            expect(customer.selected_invoice_custom_sections.reload).to contain_exactly(invoice_custom_section_2)
            expect(customer.applicable_invoice_custom_sections.reload).to contain_exactly(invoice_custom_section_2)
          end
        end

        context "when section_ids are totally custom" do
          let(:section_ids) { [invoice_custom_section_3.id] }

          before do
            create(:customer_applied_invoice_custom_section, customer:, organization:, billing_entity:, invoice_custom_section: invoice_custom_section_1)
            create(:billing_entity_applied_invoice_custom_section, organization:, billing_entity:, invoice_custom_section: invoice_custom_section_2)
          end

          it "assigns customer sections" do
            expect(result).to be_success
            expect(customer.selected_invoice_custom_sections.reload).to contain_exactly(invoice_custom_section_3)
            expect(customer.applicable_invoice_custom_sections.reload).to contain_exactly(invoice_custom_section_3)
          end
        end

        context "when setting invoice_custom_sections_ids when previously customer had skip_invoice_custom_sections" do
          let(:section_ids) { [] }

          before do
            create(:customer_applied_invoice_custom_section, customer:, organization:, billing_entity:, invoice_custom_section: invoice_custom_section_1)
            create(:billing_entity_applied_invoice_custom_section, organization:, billing_entity:, invoice_custom_section: invoice_custom_section_2)
            customer.update!(skip_invoice_custom_sections: true)
          end

          it "sets skip_invoice_custom_sections to false" do
            expect(result).to be_success
            expect(customer.reload.skip_invoice_custom_sections).to be false
            expect(customer.selected_invoice_custom_sections.reload).to be_empty
            expect(customer.applicable_invoice_custom_sections.reload).to contain_exactly(invoice_custom_section_2)
          end
        end
      end

      context "when an ActiveRecord::RecordInvalid error is raised" do
        let(:section_ids) { [invoice_custom_section_2.id] }

        before do
          allow(customer).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(customer))
        end

        it "returns record validation failure" do
          expect(result).to be_failure
          expect(result.error).to be_a(BaseService::ValidationFailure)
        end
      end
    end

    context "when sending section_codes" do
      context "when sending skip_invoice_custom_sections: true AND selected_codes" do
        let(:skip_invoice_custom_sections) { true }
        let(:section_codes) { [] }

        it "returns a validation failure" do
          expect(result).to be_failure
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.message).to include("skip_sections_and_selected_ids_sent_together")
        end
      end

      context "when updating selected_invoice_custom_sections" do
        context "when section_codes match customer's applicable sections" do
          let(:section_codes) { [invoice_custom_section_1.code] }

          it "returns the result without changes" do
            expect(result).to be_success
            expect(customer.applicable_invoice_custom_sections.reload).to contain_exactly(invoice_custom_section_1)
          end
        end

        context "when section_ids are totally custom" do
          let(:section_codes) { [invoice_custom_section_3.code] }

          it "assigns customer sections" do
            expect(result).to be_success
            expect(customer.selected_invoice_custom_sections.reload).to contain_exactly(invoice_custom_section_3)
            expect(customer.applicable_invoice_custom_sections.reload).to contain_exactly(invoice_custom_section_3)
          end
        end

        context "when setting invoice_custom_sections_ids when previously customer had skip_invoice_custom_sections" do
          let(:section_codes) { [] }

          before do
            create(:customer_applied_invoice_custom_section, customer:, organization:, billing_entity:, invoice_custom_section: invoice_custom_section_1)
            create(:billing_entity_applied_invoice_custom_section, organization:, billing_entity:, invoice_custom_section: invoice_custom_section_2)
            customer.update!(skip_invoice_custom_sections: true)
          end

          it "sets skip_invoice_custom_sections to false" do
            expect(result).to be_success
            expect(customer.reload.skip_invoice_custom_sections).to be false
            expect(customer.selected_invoice_custom_sections.reload).to be_empty
            expect(customer.applicable_invoice_custom_sections.reload).to contain_exactly(invoice_custom_section_2)
          end
        end
      end
    end

    context "when updating customer to skip_invoice_custom_sections" do
      let(:skip_invoice_custom_sections) { true }

      before do
        create(:customer_applied_invoice_custom_section, customer:, organization:, billing_entity:, invoice_custom_section: invoice_custom_section_1)
        create(:billing_entity_applied_invoice_custom_section, organization:, billing_entity:, invoice_custom_section: invoice_custom_section_2)
      end

      it "sets skip_invoice_custom_sections to true" do
        expect(result).to be_success
        expect(customer.reload.skip_invoice_custom_sections).to be true
        expect(customer.selected_invoice_custom_sections.reload).to be_empty
        expect(customer.applicable_invoice_custom_sections.reload).to be_empty
      end
    end

    context "when assigning section_ids and customer has system_generated sections" do
      let(:section_ids) { [invoice_custom_section_1.id] }

      let(:system_generated_section) do
        create(:invoice_custom_section, organization:, section_type: :system_generated)
      end

      before do
        create(:customer_applied_invoice_custom_section, customer:, organization:, billing_entity:, invoice_custom_section: system_generated_section)
      end

      it "keeps system_generated sections and adds selected manual ones" do
        expect(result).to be_success
        expect(customer.selected_invoice_custom_sections.reload).to contain_exactly(invoice_custom_section_1, system_generated_section)
      end
    end

    context "when assigning section_codes and customer has system_generated sections" do
      let(:section_codes) { [invoice_custom_section_1.code] }

      let(:system_generated_section) do
        create(:invoice_custom_section, organization:, section_type: :system_generated)
      end

      before do
        create(:customer_applied_invoice_custom_section, customer:, organization:, billing_entity:, invoice_custom_section: system_generated_section)
      end

      it "keeps system_generated sections and adds selected manual ones" do
        expect(result).to be_success
        expect(customer.selected_invoice_custom_sections.reload).to contain_exactly(invoice_custom_section_1, system_generated_section)
      end
    end

    context "when clearing all manual sections but customer has system_generated" do
      let(:section_ids) { [] }

      let(:system_generated_section) do
        create(:invoice_custom_section, organization: customer.organization, section_type: :system_generated)
      end

      before do
        create(:customer_applied_invoice_custom_section, customer:, organization:, billing_entity:, invoice_custom_section: invoice_custom_section_1)
        create(:customer_applied_invoice_custom_section, customer:, organization:, billing_entity:, invoice_custom_section: system_generated_section)
      end

      it "removes manual but keeps system_generated sections" do
        expect(result).to be_success
        expect(customer.manual_selected_invoice_custom_sections.reload).to be_empty
        expect(customer.selected_invoice_custom_sections.reload).to match_array([system_generated_section])
      end
    end
  end
end
