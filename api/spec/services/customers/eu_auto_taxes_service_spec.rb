# frozen_string_literal: true

require "rails_helper"

RSpec.describe Customers::EuAutoTaxesService do
  subject(:eu_tax_service) { described_class.new(customer:, new_record:, tax_attributes_changed:) }

  let(:organization) { create(:organization, country: "IT", eu_tax_management: true) }
  let(:billing_entity) { create(:billing_entity, organization:, country: "FR", eu_tax_management: true) }
  let(:customer) { create(:customer, organization:, billing_entity:, tax_identification_number:, zipcode: nil) }
  let(:new_record) { true }
  let(:tax_attributes_changed) { true }
  let(:tax_identification_number) { nil }

  describe ".call" do
    context "when eu_tax_management is false" do
      let(:organization) { create(:organization, country: "IT", eu_tax_management: false) }
      let(:billing_entity) { create(:billing_entity, organization:, country: "FR", eu_tax_management: false) }

      it "returns error" do
        result = eu_tax_service.call

        expect(result).not_to be_success
        expect(result.error.code).to eq("eu_tax_not_applicable")
      end
    end

    context "when customer is updated and there are eu taxes" do
      let(:new_record) { false }
      let(:tax_attributes_changed) { false }
      let(:applied_tax) { create(:customer_applied_tax, tax:, customer:) }
      let(:tax) { create(:tax, organization:, code: "lago_eu_tax_exempt") }

      before { applied_tax }

      it "returns error" do
        result = eu_tax_service.call

        expect(result).not_to be_success
        expect(result.error.code).to eq("eu_tax_not_applicable")
      end
    end

    context "when customer is updated and there are no eu taxes" do
      let(:new_record) { false }
      let(:tax_attributes_changed) { false }
      let(:applied_tax) { create(:customer_applied_tax, tax:, customer:) }
      let(:tax) { create(:tax, organization:, code: "unknown_eu_tax_exempt") }

      before do
        applied_tax
        customer.update!(country: "DE")
      end

      it "returns the customer country tax code" do
        result = eu_tax_service.call

        expect(result.tax_code).to eq("lago_eu_de_standard")
      end
    end

    context "when tax_identification_number is blank" do
      let(:tax_identification_number) { nil }

      before { customer.update!(country: "DE") }

      it "returns the customer country tax code" do
        result = eu_tax_service.call

        expect(result.tax_code).to eq("lago_eu_de_standard")
      end

      it "does not enqueue ViesCheckJob" do
        eu_tax_service.call

        expect(Customers::ViesCheckJob).not_to have_been_enqueued
      end
    end

    context "when tax_identification_number is present" do
      let(:tax_identification_number) { "IT12345678901" }

      it "creates a PendingViesCheck" do
        expect { eu_tax_service.call }.to change(PendingViesCheck, :count).by(1)

        pending_check = customer.pending_vies_check
        expect(pending_check).to have_attributes(
          organization: customer.organization,
          billing_entity: customer.billing_entity,
          tax_identification_number: customer.tax_identification_number,
          attempts_count: 0
        )
      end

      it "enqueues ViesCheckJob" do
        eu_tax_service.call

        expect(Customers::ViesCheckJob).to have_been_enqueued.with(customer)
      end

      it "returns a failure result with vies_check_pending code" do
        result = eu_tax_service.call

        expect(result).not_to be_success
        expect(result.error.code).to eq("vies_check_pending")
      end

      context "when a PendingViesCheck already exists" do
        before { create(:pending_vies_check, customer:, attempts_count: 3) }

        it "resets the existing check" do
          expect { eu_tax_service.call }.not_to change(PendingViesCheck, :count)

          pending_check = customer.pending_vies_check.reload
          expect(pending_check.attempts_count).to eq(0)
        end
      end
    end

    context "with non B2B (no TIN)" do
      let(:tax_identification_number) { nil }

      context "when the customer has no country" do
        before { customer.update(country: nil) }

        it "returns the billing entity country tax code" do
          result = eu_tax_service.call

          expect(result.tax_code).to eq("lago_eu_fr_standard")
        end
      end

      context "when the customer country is in europe" do
        before { customer.update(country: "DE") }

        it "returns the customer country tax code" do
          result = eu_tax_service.call

          expect(result.tax_code).to eq("lago_eu_de_standard")
        end
      end

      context "when the customer country is out of europe" do
        before { customer.update(country: "US") }

        it "returns the tax exempt tax code" do
          result = eu_tax_service.call

          expect(result.tax_code).to eq("lago_eu_tax_exempt")
        end
      end
    end

    context "when customer is in a special territory" do
      shared_examples "a special territory tax assignment" do |country:, zipcode:, expected_tax_code:|
        before { customer.update(country:, zipcode:) }

        it "assigns #{expected_tax_code}" do
          result = eu_tax_service.call
          expect(result.tax_code).to eq(expected_tax_code)
        end
      end

      context "when B2B customer (non-France territories apply exception regardless)" do
        let(:tax_identification_number) { "IT12345678901" }

        it_behaves_like "a special territory tax assignment",
          country: "ES", zipcode: "35001", expected_tax_code: "lago_eu_es_exception_canary_islands"
        it_behaves_like "a special territory tax assignment",
          country: "ES", zipcode: "38314", expected_tax_code: "lago_eu_es_exception_canary_islands"
        it_behaves_like "a special territory tax assignment",
          country: "ES", zipcode: "51001", expected_tax_code: "lago_eu_es_exception_ceuta"
        it_behaves_like "a special territory tax assignment",
          country: "ES", zipcode: "52001", expected_tax_code: "lago_eu_es_exception_melilla"
        it_behaves_like "a special territory tax assignment",
          country: "AT", zipcode: "6691", expected_tax_code: "lago_eu_at_exception_jungholz"
        it_behaves_like "a special territory tax assignment",
          country: "AT", zipcode: "6992", expected_tax_code: "lago_eu_at_exception_mittelberg"
        it_behaves_like "a special territory tax assignment",
          country: "AT", zipcode: "6991", expected_tax_code: "lago_eu_at_exception_mittelberg"
        it_behaves_like "a special territory tax assignment",
          country: "IT", zipcode: "23041", expected_tax_code: "lago_eu_it_exception_livigno"
        it_behaves_like "a special territory tax assignment",
          country: "IT", zipcode: "22061", expected_tax_code: "lago_eu_it_exception_campione_d_italia"
        it_behaves_like "a special territory tax assignment",
          country: "DE", zipcode: "78266", expected_tax_code: "lago_eu_de_exception_busingen_am_hochrhein"
        it_behaves_like "a special territory tax assignment",
          country: "DE", zipcode: "27498", expected_tax_code: "lago_eu_de_exception_heligoland"
        it_behaves_like "a special territory tax assignment",
          country: "PT", zipcode: "9500", expected_tax_code: "lago_eu_pt_exception_azores"
        it_behaves_like "a special territory tax assignment",
          country: "PT", zipcode: "9000", expected_tax_code: "lago_eu_pt_exception_madeira"
        it_behaves_like "a special territory tax assignment",
          country: "GR", zipcode: "63086", expected_tax_code: "lago_eu_gr_exception_mount_athos"
        it_behaves_like "a special territory tax assignment",
          country: "FI", zipcode: "22000", expected_tax_code: "lago_eu_fi_exception_aland_islands"
      end

      context "when B2C customer (non-France territories apply exception regardless)" do
        let(:tax_identification_number) { nil }

        it_behaves_like "a special territory tax assignment",
          country: "ES", zipcode: "35001", expected_tax_code: "lago_eu_es_exception_canary_islands"
        it_behaves_like "a special territory tax assignment",
          country: "AT", zipcode: "6691", expected_tax_code: "lago_eu_at_exception_jungholz"
        it_behaves_like "a special territory tax assignment",
          country: "IT", zipcode: "23041", expected_tax_code: "lago_eu_it_exception_livigno"
        it_behaves_like "a special territory tax assignment",
          country: "DE", zipcode: "78266", expected_tax_code: "lago_eu_de_exception_busingen_am_hochrhein"
        it_behaves_like "a special territory tax assignment",
          country: "PT", zipcode: "9500", expected_tax_code: "lago_eu_pt_exception_azores"
        it_behaves_like "a special territory tax assignment",
          country: "GR", zipcode: "63086", expected_tax_code: "lago_eu_gr_exception_mount_athos"
      end

      context "when B2B customer in France DOM-TOM (exception rate applies)" do
        let(:tax_identification_number) { "IT12345678901" }

        it_behaves_like "a special territory tax assignment",
          country: "FR", zipcode: "97200", expected_tax_code: "lago_eu_fr_exception_martinique"
        it_behaves_like "a special territory tax assignment",
          country: "FR", zipcode: "97100", expected_tax_code: "lago_eu_fr_exception_guadeloupe"
        it_behaves_like "a special territory tax assignment",
          country: "FR", zipcode: "97412", expected_tax_code: "lago_eu_fr_exception_reunion"
        it_behaves_like "a special territory tax assignment",
          country: "FR", zipcode: "97300", expected_tax_code: "lago_eu_fr_exception_guyane"
        it_behaves_like "a special territory tax assignment",
          country: "FR", zipcode: "97600", expected_tax_code: "lago_eu_fr_exception_mayotte"
      end

      context "when B2C customer in France DOM-TOM (standard rate applies)" do
        let(:tax_identification_number) { nil }

        it_behaves_like "a special territory tax assignment",
          country: "FR", zipcode: "97200", expected_tax_code: "lago_eu_fr_standard"
        it_behaves_like "a special territory tax assignment",
          country: "FR", zipcode: "97100", expected_tax_code: "lago_eu_fr_standard"
        it_behaves_like "a special territory tax assignment",
          country: "FR", zipcode: "97412", expected_tax_code: "lago_eu_fr_standard"
        it_behaves_like "a special territory tax assignment",
          country: "FR", zipcode: "97300", expected_tax_code: "lago_eu_fr_standard"
        it_behaves_like "a special territory tax assignment",
          country: "FR", zipcode: "97600", expected_tax_code: "lago_eu_fr_standard"
      end

      context "when territory is detected" do
        let(:tax_identification_number) { "IT12345678901" }

        before { customer.update(country: "ES", zipcode: "35001") }

        it "does not enqueue ViesCheckJob" do
          eu_tax_service.call
          expect(Customers::ViesCheckJob).not_to have_been_enqueued
        end

        it "does not send a webhook" do
          eu_tax_service.call
          expect(SendWebhookJob).not_to have_been_enqueued
        end

        context "when a pending VIES check exists" do
          before { create(:pending_vies_check, customer:) }

          it "destroys the pending VIES check" do
            expect { eu_tax_service.call }.to change(PendingViesCheck, :count).by(-1)
          end
        end
      end

      context "when zipcode contains spaces" do
        let(:tax_identification_number) { nil }

        it "normalizes the zipcode before matching" do
          customer.update(country: "ES", zipcode: " 35 001 ")
          result = eu_tax_service.call
          expect(result.tax_code).to eq("lago_eu_es_exception_canary_islands")
        end
      end

      context "when customer relocates from mainland to special territory" do
        let(:new_record) { false }
        let(:tax_attributes_changed) { true }
        let(:tax_identification_number) { nil }
        let(:applied_tax) { create(:customer_applied_tax, tax:, customer:) }
        let(:tax) { create(:tax, organization:, code: "lago_eu_es_standard") }

        before do
          applied_tax
          customer.update(country: "ES", zipcode: "35001")
        end

        it "detects the territory and assigns the exception tax code" do
          result = eu_tax_service.call
          expect(result.tax_code).to eq("lago_eu_es_exception_canary_islands")
        end
      end

      context "when customer has an invalid VAT number in a special territory" do
        let(:tax_identification_number) { "INVALID123" }

        before { customer.update(country: "FR", zipcode: "97100") }

        it "skips special territory detection and schedules async VIES check" do
          result = eu_tax_service.call

          expect(result).not_to be_success
          expect(result.error.code).to eq("vies_check_pending")
          expect(Customers::ViesCheckJob).to have_been_enqueued.with(customer)
        end
      end

      context "when territory is not detected" do
        let(:tax_identification_number) { nil }

        it "falls through when zipcode does not match any exception" do
          customer.update(country: "ES", zipcode: "28001")
          result = eu_tax_service.call
          expect(result.tax_code).to eq("lago_eu_es_standard")
        end

        it "falls through when customer has no zipcode" do
          customer.update(country: "DE")
          result = eu_tax_service.call
          expect(result.tax_code).to eq("lago_eu_de_standard")
        end

        it "falls through when customer has no country" do
          customer.update(country: nil, zipcode: "35001")
          result = eu_tax_service.call
          expect(result.tax_code).to eq("lago_eu_fr_standard")
        end
      end
    end
  end
end
