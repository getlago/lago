# frozen_string_literal: true

require "rails_helper"

RSpec.describe DunningCampaign do
  subject(:dunning_campaign) { create(:dunning_campaign) }

  it_behaves_like "paper_trail traceable"

  it do
    expect(subject).to belong_to(:organization)
    expect(subject).to have_many(:thresholds).dependent(:destroy)
    expect(subject).to have_many(:customers).dependent(:nullify)
    expect(subject).to have_many(:payment_requests).dependent(:nullify)

    expect(subject).to validate_presence_of(:name)

    expect(subject).to validate_numericality_of(:days_between_attempts).is_greater_than(0)
    expect(subject).to validate_numericality_of(:max_attempts).is_greater_than(0)

    expect(subject).to validate_uniqueness_of(:code).scoped_to(:organization_id)
  end

  describe "bcc_emails validation" do
    it do
      expect(dunning_campaign).to be_valid

      dunning_campaign.bcc_emails = nil
      expect(dunning_campaign).not_to be_valid

      dunning_campaign.bcc_emails = []
      expect(dunning_campaign).to be_valid

      dunning_campaign.bcc_emails = ["test1@example.com", "test2@example.com"]
      expect(dunning_campaign).to be_valid

      dunning_campaign.bcc_emails = ["test1@example.com", "name.com"]
      expect(dunning_campaign).not_to be_valid
      expect(dunning_campaign.errors.messages).to eq({
        bcc_emails: ["invalid_email_format[1,name.com]"]
      })
    end
  end

  describe "code validation" do
    let(:code) { "123456" }
    let(:organization) { create(:organization) }

    it "validates uniqueness of code scoped to organization_id excluding deleted records" do
      deleted_record = create(:dunning_campaign, :deleted, code:, organization:)
      expect(deleted_record).to be_valid

      record1 = create(:dunning_campaign, code:, organization:)
      expect(record1).to be_valid

      record2 = build(:dunning_campaign, code:, organization:)
      expect(record2).not_to be_valid
      expect(record2.errors[:code]).to include("value_already_exist")
    end
  end

  describe "default scope" do
    let(:deleted_dunning_campaign) { create(:dunning_campaign, :deleted) }

    before { deleted_dunning_campaign }

    it "only returns non-deleted dunning_campaign objects" do
      expect(described_class.all).to eq([])
      expect(described_class.with_discarded).to eq([deleted_dunning_campaign])
    end
  end

  describe "#reset_customers_last_attempt" do
    let(:last_dunning_campaign_attempt_at) { Time.current }
    let(:organization) { dunning_campaign.organization }

    it "resets last attempt on customers with the campaign applied explicitly" do
      customer = create(
        :customer,
        organization:,
        applied_dunning_campaign: dunning_campaign,
        last_dunning_campaign_attempt: 1,
        last_dunning_campaign_attempt_at:
      )

      expect { dunning_campaign.reset_customers_last_attempt }
        .to change { customer.reload.last_dunning_campaign_attempt }.from(1).to(0)
        .and change { customer.last_dunning_campaign_attempt_at }.from(last_dunning_campaign_attempt_at).to(nil)
    end

    context "when applied to billing entity" do
      subject(:dunning_campaign) { create(:dunning_campaign) }

      before { organization.default_billing_entity.update!(applied_dunning_campaign: dunning_campaign) }

      it "resets last attempt on customers falling back to the billing_entity campaign" do
        customer = create(
          :customer,
          organization:,
          last_dunning_campaign_attempt: 2,
          last_dunning_campaign_attempt_at:
        )

        expect { dunning_campaign.reset_customers_last_attempt }
          .to change { customer.reload.last_dunning_campaign_attempt }.from(2).to(0)
          .and change { customer.last_dunning_campaign_attempt_at }.from(last_dunning_campaign_attempt_at).to(nil)
      end
    end
  end
end
