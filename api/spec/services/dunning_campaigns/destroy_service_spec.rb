# frozen_string_literal: true

require "rails_helper"

RSpec.describe DunningCampaigns::DestroyService do
  subject(:destroy_service) { described_class.new(dunning_campaign:) }

  let(:organization) { create(:organization) }
  let(:membership) { create(:membership, organization:) }

  let(:dunning_campaign) { create(:dunning_campaign, organization:) }
  let(:dunning_campaign_threshold) { create(:dunning_campaign_threshold, dunning_campaign:) }

  before { dunning_campaign_threshold }

  describe "#call" do
    subject(:result) { destroy_service.call }

    context "when dunning campaign is not found" do
      let(:dunning_campaign) { nil }
      let(:dunning_campaign_threshold) { nil }

      it "returns an error" do
        result = destroy_service.call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("dunning_campaign_not_found")
      end
    end

    context "when lago freemium" do
      it "returns an error" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
      end

      it "does not delete the dunning campaign" do
        expect { result }.not_to change(dunning_campaign, :deleted_at)
      end
    end

    context "when lago premium", :premium do
      context "when no auto_dunning premium integration" do
        it "returns an error" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ForbiddenFailure)
        end

        it "does not delete the dunning campaign" do
          expect { result }.not_to change(dunning_campaign, :deleted_at)
        end
      end

      context "when auto_dunning premium integration" do
        let(:organization) do
          create(:organization, premium_integrations: ["auto_dunning"])
        end

        it "resets last attempt on customers" do
          customer = create(:customer, organization:, applied_dunning_campaign: dunning_campaign, last_dunning_campaign_attempt: 1)

          expect { destroy_service.call }.to change { customer.reload.last_dunning_campaign_attempt }.from(1)
            .to(0).and change { customer.applied_dunning_campaign_id }.from(dunning_campaign.id).to(nil)
        end

        it "soft deletes the dunning campaign" do
          freeze_time do
            expect { destroy_service.call }.to change(DunningCampaign, :count).by(-1)
              .and change { dunning_campaign.reload.deleted_at }.from(nil).to(Time.current)
          end
        end

        it "soft deletes the dunning campaign threshold" do
          freeze_time do
            expect { destroy_service.call }.to change(DunningCampaignThreshold, :count).by(-1)
              .and change { dunning_campaign_threshold.reload.deleted_at }.from(nil).to(Time.current)
          end
        end

        context "when dunning campaign was applied on billing_entity" do
          before { organization.default_billing_entity.update!(applied_dunning_campaign: dunning_campaign) }

          it "resets the applied dunning campaign on the billing entity" do
            expect { destroy_service.call }.to change { organization.default_billing_entity.reload.applied_dunning_campaign_id }.from(dunning_campaign.id).to(nil)
          end
        end
      end
    end
  end
end
