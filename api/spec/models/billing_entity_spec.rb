# frozen_string_literal: true

require "rails_helper"

RSpec.describe BillingEntity do
  subject(:billing_entity) { build(:billing_entity) }

  it_behaves_like "paper_trail traceable"

  it { is_expected.to belong_to(:organization) }
  it { is_expected.to belong_to(:applied_dunning_campaign).class_name("DunningCampaign").optional }

  it { is_expected.to have_many(:customers) }
  it { is_expected.to have_many(:invoices) }
  it { is_expected.to have_many(:fees) }
  it { is_expected.to have_many(:pending_vies_checks) }
  it { is_expected.to have_many(:payment_receipts) }
  it { is_expected.to have_many(:applied_invoice_custom_sections).class_name("BillingEntity::AppliedInvoiceCustomSection").dependent(:destroy) }
  it { is_expected.to have_many(:integration_collection_mappings).class_name("IntegrationCollectionMappings::BaseCollectionMapping").dependent(:destroy) }
  it { is_expected.to have_many(:integration_mappings).class_name("IntegrationMappings::BaseMapping").dependent(:destroy) }

  it { is_expected.to have_many(:subscriptions).through(:customers) }
  it { is_expected.to have_many(:wallets).through(:customers) }
  it { is_expected.to have_many(:wallet_transactions).through(:wallets) }
  it { is_expected.to have_many(:credit_notes).through(:invoices) }
  it { is_expected.to have_many(:selected_invoice_custom_sections).through(:applied_invoice_custom_sections).source(:invoice_custom_section) }
  it { is_expected.to have_many(:manual_selected_invoice_custom_sections).through(:applied_invoice_custom_sections).source(:invoice_custom_section) }
  it { is_expected.to have_many(:system_generated_selected_invoice_custom_sections).through(:applied_invoice_custom_sections).source(:invoice_custom_section) }

  it { is_expected.to have_many(:applied_taxes).dependent(:destroy) }
  it { is_expected.to have_many(:taxes).through(:applied_taxes) }

  describe "Clickhouse associations", clickhouse: true do
    it { is_expected.to have_many(:activity_logs).class_name("Clickhouse::ActivityLog") }
  end

  describe "code validation" do
    let(:organization) { create :organization }

    it "validates uniqueness of organization_id for code excluding deleted and archived records" do
      record_1 = create(:billing_entity, organization: organization)
      expect(record_1).to be_valid

      record_2 = build(:billing_entity, organization: organization, code: record_1.code)
      expect(record_2).not_to be_valid
      expect(record_2.errors[:code]).to include("value_already_exist")

      record_3 = create(:billing_entity, code: record_1.code)
      expect(record_3).to be_valid

      record_1.discard!
      record_4 = build(:billing_entity, organization: organization, code: record_1.code)
      expect(record_4).to be_valid

      record_1.undiscard!
      record_1.update(archived_at: Time.current)
      record_5 = build(:billing_entity, organization: organization, code: record_1.code)
      expect(record_5).to be_valid
    end
  end

  describe "Scopes" do
    let(:active_billing_entity_1) { create(:billing_entity, created_at: 1.week.ago) }
    let(:active_billing_entity_2) { create(:billing_entity, created_at: 2.weeks.ago) }
    let(:archived_billing_entity) { create(:billing_entity, :archived) }
    let(:deleted_billing_entity) { create(:billing_entity, :deleted) }

    before do
      active_billing_entity_1
      active_billing_entity_2
      archived_billing_entity
      deleted_billing_entity
    end

    describe ".active" do
      it "returns active billing entities ordered" do
        expect(described_class.active).to eq [active_billing_entity_2, active_billing_entity_1]
      end
    end
  end

  describe "Validations" do
    let(:billing_entity) { build(:billing_entity) }

    it "is valid with valid attributes" do
      expect(billing_entity).to be_valid
    end

    it { is_expected.to validate_length_of(:document_number_prefix).is_at_least(1).is_at_most(10).on(:update) }

    it { is_expected.to allow_value(nil).for(:document_number_prefix).on(:create) }
    it { is_expected.to validate_length_of(:document_number_prefix).is_at_least(1).is_at_most(10).on(:create) }

    it "is not valid without name" do
      billing_entity.name = nil
      expect(billing_entity).not_to be_valid
    end

    it "is invalid with invalid email" do
      billing_entity.email = "foo.bar"
      expect(billing_entity).not_to be_valid
    end

    it "is invalid with invalid country" do
      billing_entity.country = "ZWX"
      expect(billing_entity).not_to be_valid

      billing_entity.country = ""
      expect(billing_entity).not_to be_valid
    end

    it "validates the language code" do
      billing_entity.document_locale = nil
      expect(billing_entity).not_to be_valid

      billing_entity.document_locale = "en"
      expect(billing_entity).to be_valid

      billing_entity.document_locale = "foo"
      expect(billing_entity).not_to be_valid

      billing_entity.document_locale = ""
      expect(billing_entity).not_to be_valid
    end

    it "is invalid with invalid invoice footer" do
      billing_entity.invoice_footer = SecureRandom.alphanumeric(601)
      expect(billing_entity).not_to be_valid
    end

    it "is valid with logo" do
      billing_entity.logo.attach(
        io: File.open(Rails.root.join("spec/factories/images/logo.png")),
        content_type: "image/png",
        filename: "logo"
      )
      expect(billing_entity).to be_valid
    end

    it "is invalid with too big logo" do
      billing_entity.logo.attach(
        io: File.open(Rails.root.join("spec/factories/images/big_sized_logo.jpg")),
        content_type: "image/jpeg",
        filename: "logo"
      )
      expect(billing_entity).not_to be_valid
    end

    it "is invalid with unsupported logo content type" do
      billing_entity.logo.attach(
        io: File.open(Rails.root.join("spec/factories/images/logo.gif")),
        content_type: "image/gif",
        filename: "logo"
      )
      expect(billing_entity).not_to be_valid
    end

    it "is invalid with invalid timezone" do
      billing_entity.timezone = "foo"
      expect(billing_entity).not_to be_valid
    end

    it "is valid with email_settings" do
      billing_entity.email_settings = ["invoice.finalized", "credit_note.created"]
      expect(billing_entity).to be_valid
    end

    it "is invalid with non permitted email_settings value" do
      billing_entity.email_settings = ["email.not_permitted"]

      expect(billing_entity).not_to be_valid
      expect(billing_entity.errors.first.attribute).to eq(:email_settings)
      expect(billing_entity.errors.first.type).to eq(:unsupported_value)
    end

    it "dont allow finalize_zero_amount_invoice with null value" do
      expect(billing_entity.finalize_zero_amount_invoice).to eq true
      billing_entity.finalize_zero_amount_invoice = nil

      expect(billing_entity).not_to be_valid
    end

    it "validates subscription_invoice_issuing_date_anchor" do
      billing_entity.subscription_invoice_issuing_date_anchor = nil
      expect(billing_entity).not_to be_valid

      billing_entity.subscription_invoice_issuing_date_anchor = "invalid"
      expect(billing_entity).not_to be_valid

      billing_entity.subscription_invoice_issuing_date_anchor = "current_period_end"
      expect(billing_entity).to be_valid

      billing_entity.subscription_invoice_issuing_date_anchor = "next_period_start"
      expect(billing_entity).to be_valid
    end

    it "validates subscription_invoice_issuing_date_adjustments" do
      billing_entity.subscription_invoice_issuing_date_adjustment = nil
      expect(billing_entity).not_to be_valid

      billing_entity.subscription_invoice_issuing_date_adjustment = "invalid"
      expect(billing_entity).not_to be_valid

      billing_entity.subscription_invoice_issuing_date_adjustment = "keep_anchor"
      expect(billing_entity).to be_valid

      billing_entity.subscription_invoice_issuing_date_adjustment = "align_with_finalization_date"
      expect(billing_entity).to be_valid
    end
  end

  context "when validate einvoicing" do
    let(:einvoicing) { true }
    let(:country) { "FR" }

    before do
      billing_entity.einvoicing = einvoicing
      billing_entity.country = country
    end

    context "without country" do
      let(:country) { nil }

      it "is not valid" do
        expect(billing_entity).not_to be_valid
        expect(billing_entity.errors.first.attribute).to eq(:einvoicing)
        expect(billing_entity.errors.first.type).to eq(:country_must_be_present)
      end
    end

    context "with an unsupported country" do
      let(:country) { "BR" }

      it "is not valid" do
        expect(billing_entity).not_to be_valid
        expect(billing_entity.errors.first.attribute).to eq(:einvoicing)
        expect(billing_entity.errors.first.type).to eq(:country_not_supported)
      end
    end

    context "with a supported country" do
      let(:country) { "fr" }

      it "is valid" do
        expect(billing_entity).to be_valid
      end
    end

    context "when einvoincing is false" do
      let(:einvoicing) { false }
      let(:country) { "BR" }

      it "succeeds" do
        expect(billing_entity).to be_valid
      end
    end
  end

  describe "#save" do
    subject { billing_entity.save! }

    context "with a new record" do
      let(:billing_entity) { build(:billing_entity) }

      it "sets document number prefix of billing_entity" do
        subject

        expect(billing_entity.document_number_prefix)
          .to eq "#{billing_entity.name.first(3).upcase}-#{billing_entity.id.last(4).upcase}"
      end

      context "when document number prefix is already set" do
        it "does not change existing document number prefix of billing_entity" do
          billing_entity.document_number_prefix = "ABC-1234"
          subject

          expect(billing_entity.document_number_prefix).to eq "ABC-1234"
        end
      end
    end

    context "with a persisted record" do
      let(:billing_entity) { create(:billing_entity) }

      it "does not change document number prefix of billing_entity" do
        expect { subject }.not_to change(billing_entity, :document_number_prefix)
      end
    end
  end

  describe "#country=" do
    it "upcases country" do
      billing_entity.country = "us"

      expect(billing_entity.country).to eq "US"
    end
  end

  describe "#document_number_prefix=" do
    it "upcases the value" do
      billing_entity.document_number_prefix = "abc-1234"
      expect(billing_entity.document_number_prefix).to eq "ABC-1234"
    end
  end

  describe "#logo_url" do
    it "returns the url of the logo saved locally" do
      logo_file = File.read(Rails.root.join("spec/factories/images/logo.png"))
      billing_entity.logo.attach(
        io: StringIO.new(logo_file),
        filename: "logo",
        content_type: "image/png"
      )
      billing_entity.save!
      expect(billing_entity.logo_url).to include("rails/active_storage/blobs")
    end
  end

  describe "#base64_logo" do
    it "returns the base64 encoded logo" do
      logo_file = File.read(Rails.root.join("spec/factories/images/logo.png"))
      billing_entity.logo.attach(
        io: StringIO.new(logo_file),
        filename: "logo",
        content_type: "image/png"
      )
      billing_entity.save!
      expect(billing_entity.base64_logo).to eq Base64.encode64(logo_file)
    end
  end

  describe "#eu_vat_eligible?" do
    context "when country is nil" do
      it "returns false" do
        billing_entity.country = nil
        expect(billing_entity).not_to be_eu_vat_eligible
      end
    end

    context "when country is not in the EU" do
      it "returns false" do
        billing_entity.country = "US"
        expect(billing_entity).not_to be_eu_vat_eligible
      end
    end

    context "when country is in the EU" do
      it "returns true" do
        billing_entity.country = "FR"
        expect(billing_entity).to be_eu_vat_eligible
      end
    end
  end

  describe "#from_email_address" do
    subject(:from_email_address) { billing_entity.from_email_address }

    it "returns the env var email" do
      expect(from_email_address).to eq("noreply@getlago.com")
    end

    context "when organization from_email integration is enabled", :premium do
      let(:organization) { create(:organization, premium_integrations: ["from_email"]) }
      let(:billing_entity) { build(:billing_entity, organization:) }

      it "returns the billing_entity email" do
        expect(from_email_address).to eq(billing_entity.email)
      end
    end
  end

  describe "#reset_customers_last_dunning_campaign_attempt" do
    let(:last_dunning_campaign_attempt_at) { 1.day.ago }
    let(:campaign) { create(:dunning_campaign, organization: billing_entity.organization) }

    it "resets the last dunning campaign attempt for customers with fallback dunning_campaign" do
      customer1 = create(:customer, billing_entity:, last_dunning_campaign_attempt: 1, last_dunning_campaign_attempt_at:, dunning_currency_attempts: {"EUR" => 1})
      customer2 = create(:customer, billing_entity:, last_dunning_campaign_attempt: 1, last_dunning_campaign_attempt_at:, dunning_currency_attempts: {"EUR" => 1}, applied_dunning_campaign: campaign)

      expect { billing_entity.reset_customers_last_dunning_campaign_attempt }
        .to change { customer1.reload.last_dunning_campaign_attempt }.from(1).to(0)
        .and change(customer1, :last_dunning_campaign_attempt_at).from(last_dunning_campaign_attempt_at).to(nil)
        .and change(customer1, :dunning_currency_attempts).from({"EUR" => 1}).to({})
      expect(customer2.reload.last_dunning_campaign_attempt).to eq(1)
      expect(customer2.dunning_currency_attempts).to eq({"EUR" => 1})
    end
  end
end
