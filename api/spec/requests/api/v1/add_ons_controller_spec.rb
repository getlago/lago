# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::AddOnsController do
  let(:organization) { create(:organization) }
  let(:tax) { create(:tax, organization:) }

  describe "POST /api/v1/add_ons" do
    subject { post_with_token(organization, "/api/v1/add_ons", {add_on: create_params}) }

    let(:create_params) do
      {
        name: "add_on1",
        invoice_display_name: "Addon 1 invoice name",
        code: "add_on1_code",
        amount_cents: 123,
        amount_currency: "EUR",
        description: "description",
        tax_codes: [tax.code]
      }
    end

    include_examples "requires API permission", "add_on", "write"

    it "creates a add-on" do
      subject

      expect(response).to have_http_status(:success)

      expect(json[:add_on][:lago_id]).to be_present
      expect(json[:add_on][:code]).to eq(create_params[:code])
      expect(json[:add_on][:name]).to eq(create_params[:name])
      expect(json[:add_on][:invoice_display_name]).to eq(create_params[:invoice_display_name])
      expect(json[:add_on][:created_at]).to be_present
      expect(json[:add_on][:taxes].map { |t| t[:code] }).to contain_exactly(tax.code)
    end
  end

  describe "PUT /api/v1/add_ons/:code" do
    subject do
      put_with_token(organization, "/api/v1/add_ons/#{add_on_code}", {add_on: update_params})
    end

    let(:add_on) { create(:add_on, organization:) }
    let(:add_on_code) { add_on.code }
    let(:add_on_applied_tax) { create(:add_on_applied_tax, add_on:, tax:) }
    let(:code) { "add_on_code" }
    let(:tax2) { create(:tax, organization:) }

    let(:update_params) do
      {
        name: "add_on1",
        invoice_display_name: "Addon 1 updated invoice name",
        code:,
        amount_cents: 123,
        amount_currency: "EUR",
        description: "description",
        tax_codes: [tax2.code]
      }
    end

    before { add_on_applied_tax }

    include_examples "requires API permission", "add_on", "write"

    it "updates an add-on" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:add_on][:lago_id]).to eq(add_on.id)
      expect(json[:add_on][:code]).to eq(update_params[:code])
      expect(json[:add_on][:invoice_display_name]).to eq(update_params[:invoice_display_name])
      expect(json[:add_on][:taxes].map { |t| t[:code] }).to contain_exactly(tax2.code)
    end

    context "when add-on does not exist" do
      let(:add_on_code) { SecureRandom.uuid }

      it "returns not_found error" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when add-on code already exists in organization scope (validation error)" do
      let!(:add_on2) { create(:add_on, organization:) }
      let(:code) { add_on2.code }

      it "returns unprocessable_entity error" do
        subject
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "GET /api/v1/add_ons/:code" do
    subject { get_with_token(organization, "/api/v1/add_ons/#{add_on_code}") }

    let(:add_on) { create(:add_on, organization:) }
    let(:add_on_code) { add_on.code }

    include_examples "requires API permission", "add_on", "read"

    it "returns a add-on" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:add_on][:lago_id]).to eq(add_on.id)
      expect(json[:add_on][:invoice_display_name]).to eq(add_on.invoice_display_name)
      expect(json[:add_on][:code]).to eq(add_on.code)
    end

    context "when add-on does not exist" do
      let(:add_on_code) { SecureRandom.uuid }

      it "returns not found" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /api/v1/add_ons/:code" do
    subject { delete_with_token(organization, "/api/v1/add_ons/#{add_on_code}") }

    let!(:add_on) { create(:add_on, organization:) }
    let(:add_on_code) { add_on.code }

    include_examples "requires API permission", "add_on", "write"

    it "deletes a add-on" do
      expect { subject }.to change(AddOn, :count).by(-1)
    end

    it "returns deleted add-on" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:add_on][:lago_id]).to eq(add_on.id)
      expect(json[:add_on][:code]).to eq(add_on.code)
    end

    context "when add-on does not exist" do
      let(:add_on_code) { SecureRandom.uuid }

      it "returns not_found error" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /api/v1/add_ons" do
    subject { get_with_token(organization, "/api/v1/add_ons", params) }

    let(:add_on) { create(:add_on, organization:) }
    let(:params) { {} }

    before { create(:add_on_applied_tax, add_on:, tax:) }

    include_examples "requires API permission", "add_on", "read"

    it "returns add-ons" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:add_ons].count).to eq(1)
      expect(json[:add_ons].first[:lago_id]).to eq(add_on.id)
      expect(json[:add_ons].first[:code]).to eq(add_on.code)
      expect(json[:add_ons].first[:invoice_display_name]).to eq(add_on.invoice_display_name)
      expect(json[:add_ons].first[:taxes].map { |t| t[:code] }).to contain_exactly(tax.code)
    end

    context "with pagination" do
      let(:params) { {page: 1, per_page: 1} }

      before { create(:add_on, organization:) }

      it "returns add-ons with correct meta data" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:add_ons].count).to eq(1)
        expect(json[:meta][:current_page]).to eq(1)
        expect(json[:meta][:next_page]).to eq(2)
        expect(json[:meta][:prev_page]).to eq(nil)
        expect(json[:meta][:total_pages]).to eq(2)
        expect(json[:meta][:total_count]).to eq(2)
      end
    end
  end
end
