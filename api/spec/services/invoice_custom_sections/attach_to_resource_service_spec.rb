# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceCustomSections::AttachToResourceService do
  describe "#call" do
    subject { service.call }

    let(:resource) { create(:subscription) }
    let(:params) do
      {invoice_custom_section: {}}
    end

    let(:service) { described_class.new(resource:, params:) }
    let(:organization) { resource.organization }
    let(:section_1) { create(:invoice_custom_section, organization:, code: "section_code_1") }
    let(:section_2) { create(:invoice_custom_section, organization:, code: "section_code_2") }
    let(:section_3) { create(:invoice_custom_section, organization:, code: "section_code_3") }
    let(:section_4) { create(:invoice_custom_section, organization:, code: "section_code_4") }

    before do
      CurrentContext.source = "api"

      section_1
      section_2
      section_3
      section_4
    end

    shared_examples "section attachable" do
      let(:params) do
        {
          invoice_custom_section: {invoice_custom_section_codes: ["section_code_1", "section_code_3"]}
        }
      end

      it "can attach sections" do
        subject
        resource.reload

        expect(resource.skip_invoice_custom_sections).to be_falsey
        expect(resource.applied_invoice_custom_sections.count).to eq(2)
        expect(resource.applied_invoice_custom_sections.pluck(:invoice_custom_section_id)).to include(section_1.id, section_3.id)
      end
    end

    shared_examples "section skippable" do
      let(:params) do
        {invoice_custom_section: {skip_invoice_custom_sections: true}}
      end

      it "can attach sections" do
        result = subject
        resource.reload

        expect(result.success?).to be(true)
        expect(resource.skip_invoice_custom_sections).to be_truthy
        expect(resource.applied_invoice_custom_sections.count).to be_zero
      end
    end

    describe "resource attribute" do
      context "when Subscription" do
        let(:resource) { create(:subscription) }

        it_behaves_like "section attachable"
        it_behaves_like "section skippable"
      end

      context "when Wallet" do
        let(:resource) { create(:wallet) }

        it_behaves_like "section attachable"
        it_behaves_like "section skippable"
      end

      context "when RecurringTransactionRule" do
        let(:resource) { create(:recurring_transaction_rule) }

        it_behaves_like "section attachable"
        it_behaves_like "section skippable"
      end

      context "when WalletTransaction" do
        let(:resource) { create(:wallet_transaction) }

        it_behaves_like "section attachable"
        it_behaves_like "section skippable"
      end
    end

    describe "params attribute" do
      context "without invoice_custom_section param" do
        let(:params) { {} }

        before do
          allow(service).to receive(:skip_flag).and_call_original
        end

        it "does nothing" do
          result = subject

          expect(service).not_to have_received(:skip_flag)
          expect(result.success?).to be(true)
        end
      end

      context "with skip flag as true" do
        let(:params) do
          {invoice_custom_section: {skip_invoice_custom_sections: true}}
        end

        before do
          create(:subscription_applied_invoice_custom_section, subscription: resource)
        end

        it "updates the resource skip_invoice_custom_sections to true" do
          result = subject
          resource.reload

          expect(result.success?).to be(true)
          expect(resource.skip_invoice_custom_sections).to be_truthy
          expect(resource.applied_invoice_custom_sections.count).to be_zero
        end
      end

      context "with skip flag as false" do
        let(:params) do
          {invoice_custom_section: {skip_invoice_custom_sections: false}}
        end

        it "updates the resource skip_invoice_custom_sections to false" do
          result = subject
          resource.reload

          expect(result.success?).to be(true)
          expect(resource.skip_invoice_custom_sections).to be_falsey
          expect(resource.applied_invoice_custom_sections.count).to be_zero
        end

        context "when the record skip flag is previously true" do
          before { resource.update(skip_invoice_custom_sections: true) }

          it "updates the skip attribute" do
            result = subject
            resource.reload

            expect(result.success?).to be(true)
            expect(resource.skip_invoice_custom_sections).to be_falsey
            expect(resource.applied_invoice_custom_sections.count).to be_zero
          end
        end
      end

      context "without skip flag" do
        context "when resource#skip_invoice_custom_sections was previously true" do
          before { resource.update!(skip_invoice_custom_sections: true) }

          it "does nothing" do
            subject
            resource.reload

            expect(resource.skip_invoice_custom_sections).to be_truthy
            expect(resource.applied_invoice_custom_sections.count).to be_zero
          end
        end

        context "when resource#skip_invoice_custom_sections was previously false" do
          let(:params) do
            {
              invoice_custom_section: external_params
            }
          end

          before do
            resource.update!(skip_invoice_custom_sections: false)
          end

          context "with new sections" do
            context "when comes from api" do
              let(:external_params) {
                {invoice_custom_section_codes: ["section_code_1", "section_code_2"]}
              }

              before { CurrentContext.source = "api" }

              it "attach the custom sections" do
                subject
                resource.reload

                expect(resource.skip_invoice_custom_sections).to be_falsey
                expect(resource.applied_invoice_custom_sections.count).to eq(2)
                expect(resource.applied_invoice_custom_sections.pluck(:invoice_custom_section_id)).to include(section_1.id, section_2.id)
              end
            end

            context "when comes from front" do
              let(:external_params) {
                {invoice_custom_section_ids: [section_1.id, section_3.id]}
              }

              before { CurrentContext.source = "graphql" }

              it "attach the custom sections" do
                subject
                resource.reload

                expect(resource.skip_invoice_custom_sections).to be_falsey
                expect(resource.applied_invoice_custom_sections.count).to eq(2)
                expect(resource.applied_invoice_custom_sections.pluck(:invoice_custom_section_id)).to include(section_1.id, section_3.id)
              end
            end
          end

          context "when existing sections" do
            context "with single section replace" do
              let(:external_params) {
                {invoice_custom_section_codes: ["section_code_2"]}
              }

              before do
                CurrentContext.source = "api"
                resource.applied_invoice_custom_sections.create(
                  invoice_custom_section: section_1,
                  organization:
                )
              end

              it "removes old sections" do
                subject
                resource.reload

                expect(resource.skip_invoice_custom_sections).to be_falsey
                expect(resource.applied_invoice_custom_sections.count).to eq(1)
                expect(resource.applied_invoice_custom_sections.pluck(:invoice_custom_section_id)).to include(section_2.id)
              end
            end

            context "when multiple sections update" do
              let(:external_params) {
                {invoice_custom_section_codes: ["section_code_1", "section_code_3", "section_code_4"]}
              }

              before do
                CurrentContext.source = "api"
                [section_1, section_2, section_3].each do |section|
                  resource.applied_invoice_custom_sections.create(
                    invoice_custom_section: section,
                    organization:
                  )
                end
              end

              it "replace old sections" do
                subject
                resource.reload

                expect(resource.skip_invoice_custom_sections).to be_falsey
                expect(resource.applied_invoice_custom_sections.count).to eq(3)
                expect(resource.applied_invoice_custom_sections.pluck(:invoice_custom_section_id)).to include(section_1.id, section_3.id, section_4.id)
              end
            end

            context "when zero sections are passed" do
              let(:external_params) {
                {invoice_custom_section_codes: []}
              }

              before do
                CurrentContext.source = "api"
                [section_1, section_2, section_3].each do |section|
                  resource.applied_invoice_custom_sections.create(
                    invoice_custom_section: section,
                    organization:
                  )
                end
              end

              it "remove all sections" do
                subject
                resource.reload

                expect(resource.skip_invoice_custom_sections).to be_falsey
                expect(resource.applied_invoice_custom_sections.count).to be_zero
              end
            end
          end
        end
      end

      context "when invoice_custom_section_codes" do
        let(:params) do
          {
            invoice_custom_section: {
              invoice_custom_section_codes:
            }
          }
        end

        before do
          CurrentContext.source = "api"
          [section_1, section_2, section_3].each do |section|
            resource.applied_invoice_custom_sections.create(
              invoice_custom_section: section,
              organization:
            )
          end
        end

        context "when param is empty" do
          let(:invoice_custom_section_codes) { [] }

          it "does remove all sections" do
            subject
            resource.reload

            expect(resource.skip_invoice_custom_sections).to be_falsey
            expect(resource.applied_invoice_custom_sections.count).to be_zero
          end
        end

        context "when param is not sent" do
          let(:params) do
            {
              invoice_custom_section: {skip_invoice_custom_sections: false}
            }
          end

          it "does not remove sections" do
            subject
            resource.reload

            expect(resource.skip_invoice_custom_sections).to be_falsey
            expect(resource.applied_invoice_custom_sections.count).to eq(3)
          end
        end
      end
    end
  end
end
