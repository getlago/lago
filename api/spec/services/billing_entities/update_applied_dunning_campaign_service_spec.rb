# frozen_string_literal: true

require "rails_helper"

RSpec.describe BillingEntities::UpdateAppliedDunningCampaignService do
  subject(:update_service) { described_class.new(billing_entity:, applied_dunning_campaign_id:) }

  include_context "with mocked security logger"

  let(:billing_entity) { create(:billing_entity) }
  let(:organization) { billing_entity.organization }
  let(:second_billing_entity) { create(:billing_entity, organization:) }
  let(:dunning_campaign_1) { create(:dunning_campaign, organization:) }
  let(:dunning_campaign_2) { create(:dunning_campaign, organization:) }
  let(:customer_1) { create(:customer, organization:, billing_entity:, last_dunning_campaign_attempt: 2, last_dunning_campaign_attempt_at: 1.day.ago) }
  let(:customer_2) { create(:customer, organization:, billing_entity:, last_dunning_campaign_attempt: 1, last_dunning_campaign_attempt_at: 1.day.ago, applied_dunning_campaign: dunning_campaign_2) }
  let(:customer_3) { create(:customer, organization:, billing_entity: second_billing_entity, last_dunning_campaign_attempt: 2, last_dunning_campaign_attempt_at: 1.day.ago, applied_dunning_campaign: dunning_campaign_1) }
  let(:customer_4) { create(:customer, organization:, billing_entity: second_billing_entity, last_dunning_campaign_attempt: 1, last_dunning_campaign_attempt_at: 1.day.ago) }

  describe "#call" do
    context "when billing entity exists" do
      before do
        customer_1
        customer_2
        customer_3
        customer_4
      end

      context "when updating applied dunning campaign to nil" do
        let(:applied_dunning_campaign_id) { nil }

        context "when billing entity has no applied dunning campaign" do
          it "does not update the billing entity" do
            expect { update_service.call }.to not_change { billing_entity.reload.applied_dunning_campaign }
          end

          it "does not reset customer attempts" do
            expect { update_service.call }.to not_change { customer_1.reload.last_dunning_campaign_attempt }
              .and not_change { customer_2.reload.last_dunning_campaign_attempt }
              .and not_change { customer_3.reload.last_dunning_campaign_attempt }
              .and not_change { customer_4.reload.last_dunning_campaign_attempt }
          end
        end

        context "when billing entity has an applied dunning campaign" do
          before do
            billing_entity.update!(applied_dunning_campaign: dunning_campaign_1)
          end

          it "removes the applied dunning campaign" do
            expect { update_service.call }
              .to change { billing_entity.reload.applied_dunning_campaign }
              .from(dunning_campaign_1)
              .to(nil)
          end

          it "resets customer attempts only on fallback customers for this billing entity" do
            expect {
              update_service.call
            }.to change { customer_1.reload.last_dunning_campaign_attempt }
              .from(2)
              .to(0)
              .and not_change { customer_2.reload.last_dunning_campaign_attempt }
              .and not_change { customer_3.reload.last_dunning_campaign_attempt }
              .and not_change { customer_4.reload.last_dunning_campaign_attempt }
          end
        end
      end

      context "when dunning campaign is provided" do
        let(:applied_dunning_campaign_id) { dunning_campaign_2.id }

        it "returns success" do
          result = update_service.call
          expect(result).to be_success
          expect(result.billing_entity).to eq(billing_entity)
          expect(result.billing_entity.applied_dunning_campaign).to eq(dunning_campaign_2)
        end

        context "when billing entity has no applied dunning campaign" do
          it "sets the new dunning campaign" do
            expect { update_service.call }
              .to change { billing_entity.reload.applied_dunning_campaign }
              .from(nil)
              .to(dunning_campaign_2)
          end

          it_behaves_like "produces a security log", "billing_entity.updated" do
            before { update_service.call }
          end

          it "resets only fallback customers of this billing entity attempts" do
            expect { update_service.call }
              .to change { customer_1.reload.last_dunning_campaign_attempt }
              .from(2)
              .to(0)
              .and not_change { customer_2.reload.last_dunning_campaign_attempt }
              .and not_change { customer_3.reload.last_dunning_campaign_attempt }
              .and not_change { customer_4.reload.last_dunning_campaign_attempt }
          end
        end

        context "when billing entity has a different applied dunning campaign" do
          before do
            billing_entity.update!(applied_dunning_campaign: dunning_campaign_1)
          end

          it "updates to the new dunning campaign" do
            expect { update_service.call }
              .to change { billing_entity.reload.applied_dunning_campaign }
              .from(dunning_campaign_1)
              .to(dunning_campaign_2)
          end

          it "resets customer attempts only on fallback customers for this billing entity" do
            expect { update_service.call }
              .to change { customer_1.reload.last_dunning_campaign_attempt }
              .from(2)
              .to(0)
              .and not_change { customer_2.reload.last_dunning_campaign_attempt }
              .and not_change { customer_3.reload.last_dunning_campaign_attempt }
              .and not_change { customer_4.reload.last_dunning_campaign_attempt }
          end
        end

        context "when billing entity has the same applied dunning campaign" do
          before do
            billing_entity.update!(applied_dunning_campaign: dunning_campaign_2)
          end

          it "does not update the billing entity" do
            expect { update_service.call }.not_to change { billing_entity.reload.applied_dunning_campaign }
          end

          it_behaves_like "does not produce a security log" do
            before { update_service.call }
          end

          it "does not reset customer attempts" do
            expect { update_service.call }.to not_change { customer_1.reload.last_dunning_campaign_attempt }
              .and not_change { customer_2.reload.last_dunning_campaign_attempt }
              .and not_change { customer_3.reload.last_dunning_campaign_attempt }
              .and not_change { customer_4.reload.last_dunning_campaign_attempt }
          end
        end
      end
    end

    context "when billing entity is nil" do
      let(:billing_entity) { nil }
      let(:organization) { create(:organization) }
      let(:dunning_campaign) { dunning_campaign_1 }
      let(:applied_dunning_campaign_id) { dunning_campaign_1.id }

      it "returns a not found failure" do
        result = update_service.call
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("billing_entity_not_found")
      end
    end

    context "when dunning campaign is not found" do
      let(:applied_dunning_campaign_id) { "nonexistent-id" }

      it "returns a not found failure" do
        result = update_service.call
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("dunning_campaign_not_found")
      end
    end
  end
end
