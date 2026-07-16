# frozen_string_literal: true

require "rails_helper"

RSpec.describe DunningCampaigns::CreateService do
  subject(:create_service) { described_class.new(organization:, params:) }

  let(:organization) { create :organization }
  let(:billing_entity) { organization.default_billing_entity }
  let(:params) do
    {
      name: "Dunning Campaign",
      code: "dunning-campaign",
      days_between_attempts: 1,
      max_attempts: 3,
      description: "Dunning Campaign Description",
      applied_to_organization:,
      thresholds:
    }
  end

  let(:applied_to_organization) { false }

  let(:thresholds) do
    [
      {amount_cents: 10000, currency: "USD"},
      {amount_cents: 20000, currency: "EUR"}
    ]
  end

  describe "#call" do
    context "when lago freemium" do
      it "returns an error" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
      end

      it "does not update the dunning campaign" do
        expect { create_service.call }.not_to change(DunningCampaign, :count)
      end
    end

    context "when lago premium", :premium do
      context "when no auto_dunning premium integration" do
        it "returns an error" do
          result = create_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ForbiddenFailure)
        end
      end

      context "when auto_dunning premium integration" do
        let(:organization) do
          create(:organization, premium_integrations: ["auto_dunning"])
        end

        it "creates a dunning campaign" do
          expect { create_service.call }.to change(DunningCampaign, :count).by(1)
            .and change(DunningCampaignThreshold, :count).by(2)
        end

        it "returns dunning campaign in the result" do
          result = create_service.call
          expect(result.dunning_campaign).to be_a(DunningCampaign)
          expect(result.dunning_campaign.thresholds.first).to be_a(DunningCampaignThreshold)
          expect(result.dunning_campaign.bcc_emails).to eq([])
        end

        context "when bcc_emails" do
          it do
            result = described_class.new(organization:, params: params.merge(bcc_emails: ["earl@example.com"])).call

            expect(result.dunning_campaign.bcc_emails).to eq(["earl@example.com"])
          end
        end

        context "with a previous dunning campaign set as applied on default billing entity" do
          let(:dunning_campaign_2) do
            create(:dunning_campaign, organization:)
          end

          before { billing_entity.update!(applied_dunning_campaign: dunning_campaign_2) }

          it "does not change previous dunning campaign applied on default billing entity" do
            expect { create_service.call }
              .not_to change(billing_entity, :applied_dunning_campaign)
          end
        end

        context "with applied_to_organization true" do
          let(:applied_to_organization) { true }

          it "updates the default billing entity with applied_dunning_campaign" do
            result = create_service.call

            expect(result).to be_success
            expect(organization.default_billing_entity.applied_dunning_campaign).to eq(result.dunning_campaign)
          end

          context "with a previous dunning campaign set as applied on default billing entity" do
            let(:dunning_campaign_2) do
              create(:dunning_campaign, organization:)
            end

            before { billing_entity.update!(applied_dunning_campaign: dunning_campaign_2) }

            it "changes applied_dunning_campaign_id on the default billing entity" do
              result = create_service.call
              expect(result).to be_success
              expect(billing_entity.reload.applied_dunning_campaign).to eq(result.dunning_campaign)
            end
          end

          it "stops and resets counters on customers" do
            customer = create(:customer, organization:, last_dunning_campaign_attempt: 1, last_dunning_campaign_attempt_at: Time.current)

            expect { create_service.call }.to change { customer.reload.last_dunning_campaign_attempt }.from(1).to(0)
              .and change { customer.last_dunning_campaign_attempt_at }.from(a_value).to(nil)
          end
        end

        context "with validation error" do
          before do
            create(:dunning_campaign, organization:, code: "dunning-campaign")
          end

          it "returns an error" do
            result = create_service.call

            expect(result).not_to be_success
            expect(result.error).to be_a(BaseService::ValidationFailure)
            expect(result.error.messages[:code]).to eq(["value_already_exist"])
          end
        end

        context "without thresholds" do
          let(:thresholds) { [] }

          it "returns an error" do
            result = create_service.call

            expect(result).not_to be_success
            expect(result.error).to be_a(BaseService::ValidationFailure)
            expect(result.error.messages[:thresholds]).to eq(["can't be blank"])
          end
        end
      end
    end
  end
end
