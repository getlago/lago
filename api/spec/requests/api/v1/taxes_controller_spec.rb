# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::TaxesController do
  let(:organization) { create(:organization) }

  describe "POST /api/v1/taxes" do
    subject { post_with_token(organization, "/api/v1/taxes", {tax: create_params}) }

    let(:create_params) do
      {
        name: "tax",
        code: "tax_code",
        rate: 20.0,
        description: "tax_description",
        applied_to_organization: false
      }
    end

    include_examples "requires API permission", "tax", "write"

    it "creates a tax" do
      expect { subject }.to change(Tax, :count).by(1)

      expect(response).to have_http_status(:success)
      expect(json[:tax][:lago_id]).to be_present
      expect(json[:tax][:code]).to eq(create_params[:code])
      expect(json[:tax][:name]).to eq(create_params[:name])
      expect(json[:tax][:rate]).to eq(create_params[:rate])
      expect(json[:tax][:description]).to eq(create_params[:description])
      expect(json[:tax][:created_at]).to be_present
      expect(json[:tax][:applied_to_organization]).to eq(create_params[:applied_to_organization])
    end
  end

  describe "PUT /api/v1/taxes/:code" do
    subject do
      put_with_token(
        organization,
        "/api/v1/taxes/#{tax_code}",
        {tax: update_params}
      )
    end

    let(:tax) { create(:tax, organization:) }
    let(:tax_code) { tax.code }
    let(:code) { "code_updated" }
    let(:name) { "name_updated" }
    let(:rate) { 15.0 }
    let(:applied_to_organization) { false }

    let(:update_params) do
      {code:, name:, rate:, applied_to_organization:}
    end

    include_examples "requires API permission", "tax", "write"

    it "updates a tax" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:tax][:lago_id]).to eq(tax.id)
      expect(json[:tax][:code]).to eq(update_params[:code])
      expect(json[:tax][:name]).to eq(update_params[:name])
      expect(json[:tax][:rate]).to eq(update_params[:rate])
      expect(json[:tax][:applied_to_organization]).to eq(update_params[:applied_to_organization])
    end

    context "when tax does not exist" do
      let(:tax_code) { SecureRandom.uuid }

      it "returns not_found error" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when tax code already exists in organization scope (validation error)" do
      let(:tax2) { create(:tax, organization:) }
      let(:code) { tax2.code }

      it "returns unprocessable_entity error" do
        subject
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "GET /api/v1/taxes/:code" do
    subject { get_with_token(organization, "/api/v1/taxes/#{tax_code}") }

    let(:tax) { create(:tax, organization:) }
    let(:tax_code) { tax.code }

    include_examples "requires API permission", "tax", "read"

    it "returns a tax" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:tax][:lago_id]).to eq(tax.id)
      expect(json[:tax][:code]).to eq(tax.code)
    end

    context "when tax does not exist" do
      let(:tax_code) { SecureRandom.uuid }

      it "returns not found" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /api/v1/taxes/:code" do
    subject { delete_with_token(organization, "/api/v1/taxes/#{tax_code}") }

    let!(:tax) { create(:tax, organization:) }
    let(:tax_code) { tax.code }

    include_examples "requires API permission", "tax", "write"

    it "deletes a tax" do
      expect { subject }.to change(Tax, :count).by(-1)
    end

    it "returns deleted tax" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:tax][:lago_id]).to eq(tax.id)
      expect(json[:tax][:code]).to eq(tax.code)
    end

    context "when tax does not exist" do
      let(:tax_code) { SecureRandom.uuid }

      it "returns not_found error" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /api/v1/taxes" do
    subject { get_with_token(organization, "/api/v1/taxes?page=1&per_page=1") }

    let!(:tax) { create(:tax, organization:) }

    include_examples "requires API permission", "tax", "read"

    it "returns taxes" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:taxes].count).to eq(1)
      expect(json[:taxes].first[:lago_id]).to eq(tax.id)
      expect(json[:taxes].first[:code]).to eq(tax.code)
    end

    context "with pagination" do
      before { create(:tax, organization:) }

      it "returns taxes with correct meta data" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:taxes].count).to eq(1)
        expect(json[:meta][:current_page]).to eq(1)
        expect(json[:meta][:next_page]).to eq(2)
        expect(json[:meta][:prev_page]).to eq(nil)
        expect(json[:meta][:total_pages]).to eq(2)
        expect(json[:meta][:total_count]).to eq(2)
      end
    end
  end
end
