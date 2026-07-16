# frozen_string_literal: true

require "rails_helper"

RSpec.describe DunningCampaigns::UpdateService do
  subject(:update_service) { described_class.new(organization:, dunning_campaign:, params:) }

  let(:organization) { create(:organization) }
  let(:billing_entity) { organization.default_billing_entity }
  let(:billing_entity_2) { create(:billing_entity, organization:) }
  let(:membership) { create(:membership, organization:) }
  let(:dunning_campaign) do
    create(:dunning_campaign, organization:)
  end

  let(:params) { {applied_to_organization: false} }

  describe "#call" do
    subject(:result) { update_service.call }

    before do
      billing_entity.update!(applied_dunning_campaign: dunning_campaign)
    end

    context "when lago freemium" do
      it "returns an error" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
      end

      it "does not change the applied dunning campaign on the billing entity" do
        expect { result }.to not_change(billing_entity, :applied_dunning_campaign_id)
      end
    end

    context "when lago premium", :premium do
      context "when no auto_dunning premium integration" do
        it "returns an error" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ForbiddenFailure)
        end

        it "does not change the applied dunning campaign on the billing entity" do
          expect { result }.to not_change(billing_entity, :applied_dunning_campaign_id)
        end
      end

      context "when auto_dunning premium integration" do
        let(:organization) do
          create(:organization, premium_integrations: ["auto_dunning"])
        end

        let(:dunning_campaign_threshold) do
          create(:dunning_campaign_threshold, dunning_campaign:)
        end

        let(:params) do
          {
            name: "Updated Dunning Campaign",
            code: "updated-dunning-campaign",
            days_between_attempts: Faker::Number.number(digits: 2),
            max_attempts: Faker::Number.number(digits: 2),
            description: "Updated Dunning Campaign Description",
            thresholds: thresholds_input
          }
        end

        let(:thresholds_input) do
          [
            {
              id: dunning_campaign_threshold.id,
              amount_cents: 999_99,
              currency: "GBP"
            },
            {
              amount_cents: 5_55,
              currency: "CHF"
            }
          ]
        end

        let(:customer_defaulting) do
          create(
            :customer,
            currency: dunning_campaign_threshold.currency,
            applied_dunning_campaign: nil,
            last_dunning_campaign_attempt: 4,
            last_dunning_campaign_attempt_at: 1.day.ago,
            dunning_currency_attempts: {dunning_campaign_threshold.currency => 4},
            organization: organization,
            billing_entity: billing_entity
          )
        end
        let(:customer_assigned) do
          create(
            :customer,
            currency: dunning_campaign_threshold.currency,
            applied_dunning_campaign: dunning_campaign,
            last_dunning_campaign_attempt: 4,
            last_dunning_campaign_attempt_at: 1.day.ago,
            dunning_currency_attempts: {dunning_campaign_threshold.currency => 4},
            organization: organization,
            billing_entity: billing_entity
          )
        end
        let(:customer_from_another_billing_entity) do
          create(
            :customer,
            currency: dunning_campaign_threshold.currency,
            applied_dunning_campaign: nil,
            last_dunning_campaign_attempt: 4,
            last_dunning_campaign_attempt_at: 1.day.ago,
            dunning_currency_attempts: {dunning_campaign_threshold.currency => 4},
            organization: organization,
            billing_entity: billing_entity_2
          )
        end

        it "updates the dunning campaign" do
          expect(result).to be_success
          expect(result.dunning_campaign.name).to eq(params[:name])
          expect(result.dunning_campaign.bcc_emails).to eq([])
          expect(result.dunning_campaign.code).to eq(params[:code])
          expect(result.dunning_campaign.days_between_attempts).to eq(params[:days_between_attempts])
          expect(result.dunning_campaign.max_attempts).to eq(params[:max_attempts])
          expect(result.dunning_campaign.description).to eq(params[:description])

          expect(result.dunning_campaign.thresholds.count).to eq(2)
          expect(result.dunning_campaign.thresholds.find(dunning_campaign_threshold.id))
            .to have_attributes({amount_cents: 999_99, currency: "GBP"})
          expect(result.dunning_campaign.thresholds.where.not(id: dunning_campaign_threshold.id).first)
            .to have_attributes({amount_cents: 5_55, currency: "CHF"})
        end

        context "when bcc_emails is set and should be reset" do
          let(:dunning_campaign) { create(:dunning_campaign, organization:, bcc_emails: ["earl@example.com"]) }
          let(:params) do
            {
              name: "Updated Dunning Campaign",
              bcc_emails: []
            }
          end

          it "updates the dunning campaign" do
            expect(result).to be_success
            expect(result.dunning_campaign.name).to eq(params[:name])
            expect(result.dunning_campaign.bcc_emails).to eq([])
          end
        end

        shared_examples "resets customer last dunning campaign attempt fields" do |customer_name|
          let(:customer) { send(customer_name) }

          before { customer }

          it "resets the customer's dunning campaign fields" do
            expect { result && customer.reload }
              .to change(customer, :last_dunning_campaign_attempt).to(0)
              .and change(customer, :last_dunning_campaign_attempt_at).to(nil)
              .and change(customer, :dunning_currency_attempts).to({})

            expect(result).to be_success
          end
        end

        shared_examples "does not reset customer last dunning campaign attempt fields" do |customer_name|
          let(:customer) { send(customer_name) }

          before { customer }

          it "does not reset the customer's dunning campaign fields" do
            expect { result && customer.reload }
              .to not_change { customer.last_dunning_campaign_attempt }
              .and not_change { customer.last_dunning_campaign_attempt_at&.to_i }
              .and not_change { customer.dunning_currency_attempts }

            expect(result).to be_success
          end
        end

        context "when threshold amount_cents changes and does not apply anymore to the customer" do
          let(:thresholds_input) do
            [
              {
                id: dunning_campaign_threshold.id,
                amount_cents: threshold_amount_cents,
                currency: dunning_campaign_threshold.currency
              }
            ]
          end

          let(:threshold_amount_cents) { 999_99 }

          before do
            create(
              :invoice,
              organization:,
              customer:,
              payment_overdue: true,
              total_amount_cents: (threshold_amount_cents - 1),
              currency: dunning_campaign_threshold.currency
            )
          end

          context "when the campaign is assigned to the customer" do
            let(:dunning_campaign) do
              create(:dunning_campaign, organization:)
            end

            include_examples "resets customer last dunning campaign attempt fields", :customer_assigned
          end

          context "when the customer defaults to the campaign applied to billing entity" do
            include_examples "resets customer last dunning campaign attempt fields", :customer_defaulting
          end

          context "when the customer defaults to the campaign applied to another billing entity" do
            include_examples "does not reset customer last dunning campaign attempt fields", :customer_from_another_billing_entity
          end
        end

        context "when threshold currency changes and does not apply anymore to the customer" do
          let(:thresholds_input) do
            [
              {
                id: dunning_campaign_threshold.id,
                amount_cents: dunning_campaign_threshold.amount_cents,
                currency: "GBP"
              }
            ]
          end

          before do
            create(
              :invoice,
              organization:,
              customer:,
              payment_overdue: true,
              total_amount_cents: dunning_campaign_threshold.amount_cents + 1,
              currency: dunning_campaign_threshold.currency
            )
          end

          context "when the campaign is assigned to the customer" do
            let(:dunning_campaign) do
              create(:dunning_campaign, organization:)
            end

            include_examples "resets customer last dunning campaign attempt fields", :customer_assigned
          end

          context "when the customer defaults to the campaign applied to organization" do
            include_examples "resets customer last dunning campaign attempt fields", :customer_defaulting
          end

          context "when the customer defaults to the campaign applied to another billing entity" do
            include_examples "does not reset customer last dunning campaign attempt fields", :customer_from_another_billing_entity
          end
        end

        context "when threshold amount_cents changes but it still applies to the customer" do
          let(:thresholds_input) do
            [
              {
                id: dunning_campaign_threshold.id,
                amount_cents: threshold_amount_cents,
                currency: dunning_campaign_threshold.currency
              }
            ]
          end

          let(:threshold_amount_cents) { 50_00 }

          before do
            create(
              :invoice,
              organization:,
              customer:,
              payment_overdue: true,
              total_amount_cents: (threshold_amount_cents + 1),
              currency: dunning_campaign_threshold.currency
            )
          end

          context "when the campaign is assigned to the customer" do
            let(:dunning_campaign) do
              create(:dunning_campaign, organization:)
            end

            include_examples "does not reset customer last dunning campaign attempt fields", :customer_assigned
          end

          context "when the customer defaults to the campaign applied to organization" do
            include_examples "does not reset customer last dunning campaign attempt fields", :customer_defaulting
          end

          context "when the customer defaults to the campaign applied to another billing entity" do
            include_examples "does not reset customer last dunning campaign attempt fields", :customer_from_another_billing_entity
          end
        end

        context "when customer has overdue invoices in a non-default currency matching a threshold" do
          let(:dunning_campaign) { create(:dunning_campaign, organization:) }
          let(:dunning_campaign_threshold) { create(:dunning_campaign_threshold, dunning_campaign:, currency: "EUR") }

          let(:usd_threshold) do
            create(:dunning_campaign_threshold, dunning_campaign:, currency: "USD", amount_cents: 50_00)
          end

          let(:thresholds_input) do
            [
              {
                id: dunning_campaign_threshold.id,
                amount_cents: dunning_campaign_threshold.amount_cents,
                currency: "EUR"
              },
              {
                id: usd_threshold.id,
                amount_cents: 40_00,
                currency: "USD"
              }
            ]
          end

          let(:multi_currency_customer) do
            create(
              :customer,
              currency: "EUR",
              applied_dunning_campaign: dunning_campaign,
              last_dunning_campaign_attempt: 3,
              last_dunning_campaign_attempt_at: 1.day.ago,
              dunning_currency_attempts: {"EUR" => 3},
              organization:,
              billing_entity:
            )
          end

          before do
            usd_threshold
            create(
              :invoice,
              organization:,
              customer: multi_currency_customer,
              payment_overdue: true,
              total_amount_cents: 45_00,
              currency: "USD"
            )
          end

          include_examples "does not reset customer last dunning campaign attempt fields", :multi_currency_customer
        end

        context "when threshold currency changes but it still applies to the customer" do
          let(:thresholds_input) do
            [
              {
                id: not_matching_threshold.id,
                amount_cents: 999_99,
                currency: "GBP"
              },
              {
                id: dunning_campaign_threshold.id,
                amount_cents: dunning_campaign_threshold.amount_cents,
                currency: dunning_campaign_threshold.currency
              }
            ]
          end

          let(:not_matching_threshold) do
            create(:dunning_campaign_threshold, dunning_campaign:, currency: "CHF")
          end

          before do
            create(
              :invoice,
              organization:,
              customer:,
              payment_overdue: true,
              total_amount_cents: dunning_campaign_threshold.amount_cents + 1,
              currency: dunning_campaign_threshold.currency
            )
          end

          context "when the campaign is assigned to the customer" do
            let(:dunning_campaign) do
              create(:dunning_campaign, organization:)
            end

            include_examples "does not reset customer last dunning campaign attempt fields", :customer_assigned
          end

          context "when the customer defaults to the campaign applied to organization" do
            include_examples "does not reset customer last dunning campaign attempt fields", :customer_defaulting
          end

          context "when the customer defaults to the campaign applied to another billing entity" do
            include_examples "does not reset customer last dunning campaign attempt fields", :customer_from_another_billing_entity
          end
        end

        context "when a threshold is discarded and the campaign does not apply anymore to the customer" do
          let(:thresholds_input) { [] } # No thresholds remain.

          before do
            create(
              :invoice,
              organization:,
              customer:,
              payment_overdue: true,
              total_amount_cents: (dunning_campaign_threshold.amount_cents + 1),
              currency: dunning_campaign_threshold.currency
            )
          end

          context "when the campaign is assigned to the customer" do
            let(:dunning_campaign) do
              create(:dunning_campaign, organization:)
            end

            include_examples "resets customer last dunning campaign attempt fields", :customer_assigned
          end

          context "when the customer defaults to the campaign applied to organization" do
            include_examples "resets customer last dunning campaign attempt fields", :customer_defaulting
          end

          context "when the customer defaults to the campaign applied to another billing entity" do
            include_examples "does not reset customer last dunning campaign attempt fields", :customer_from_another_billing_entity
          end
        end

        context "when a threshold is discarded and replaced with one that still applies to the customer" do
          let(:thresholds_input) do
            [
              {
                amount_cents: threshold_amount_cents,
                currency: dunning_campaign_threshold.currency
              }
            ]
          end

          let(:threshold_amount_cents) { 1_00 }

          before do
            create(
              :invoice,
              organization:,
              customer:,
              payment_overdue: true,
              total_amount_cents: (threshold_amount_cents + 1),
              currency: dunning_campaign_threshold.currency
            )
          end

          context "when the campaign is assigned to the customer" do
            let(:dunning_campaign) do
              create(:dunning_campaign, organization:)
            end

            include_examples "does not reset customer last dunning campaign attempt fields", :customer_assigned
          end

          context "when the customer defaults to the campaign applied to organization" do
            include_examples "does not reset customer last dunning campaign attempt fields", :customer_defaulting
          end

          context "when the customer defaults to the campaign applied to another billing entity" do
            include_examples "does not reset customer last dunning campaign attempt fields", :customer_from_another_billing_entity
          end
        end

        context "when the input does not include a thresholds" do
          let(:dunning_campaign_threshold_to_be_deleted) do
            create(:dunning_campaign_threshold, dunning_campaign:, currency: "EUR")
          end

          before { dunning_campaign_threshold_to_be_deleted }

          it "deletes the thresholds not in the input" do
            expect(result).to be_success
            expect(result.dunning_campaign.thresholds.count).to eq(2)
            expect(result.dunning_campaign.thresholds.find_by(id: dunning_campaign_threshold_to_be_deleted.id)).to be_nil
            expect(dunning_campaign_threshold_to_be_deleted.reload).to be_discarded
          end
        end

        context "with applied_to_organization false" do
          let(:params) { {applied_to_organization: false} }

          before do
            customer_assigned.reload
            customer_defaulting.reload
            customer_from_another_billing_entity.reload
          end

          it "unassigns dunning_campaign from the default billing entity" do
            expect { result }.to change { organization.default_billing_entity.applied_dunning_campaign_id }
              .from(dunning_campaign.id).to(nil)
          end

          it "resets the defaulting customers last dunning campaign attempt fields" do
            expect { result }.to change { customer_defaulting.reload.last_dunning_campaign_attempt }.to(0)
              .and change(customer_defaulting, :last_dunning_campaign_attempt_at).to(nil)
          end

          it "does not reset the customers from another billing entity last dunning campaign attempt fields" do
            expect { result }.to not_change { customer_from_another_billing_entity.reload.last_dunning_campaign_attempt }
              .and not_change { customer_from_another_billing_entity.last_dunning_campaign_attempt_at }
          end

          it "does not reset the assigned customers last dunning campaign attempt fields" do
            expect { result }.to not_change { customer_assigned.reload.last_dunning_campaign_attempt }
              .and not_change { customer_assigned.last_dunning_campaign_attempt_at }
          end
        end

        context "with applied_to_organization true" do
          let(:params) { {applied_to_organization: true} }

          let(:dunning_campaign) do
            create(:dunning_campaign, organization:)
          end

          before do
            billing_entity.update!(applied_dunning_campaign: nil)
          end

          it "updates applied_dunning_campaign_id on the default billing entity" do
            expect { result }.to change { organization.default_billing_entity.applied_dunning_campaign_id }
              .from(nil).to(dunning_campaign.id)
          end

          context "with a previous dunning campaign is applied to the default billing entity" do
            let(:dunning_campaign_2) do
              create(:dunning_campaign, organization:)
            end

            before do
              billing_entity.update!(applied_dunning_campaign: dunning_campaign_2)
            end

            it "changes applied_dunning_campaign_id on the default billing entity" do
              expect { result }.to change { organization.default_billing_entity.applied_dunning_campaign_id }
                .from(dunning_campaign_2.id).to(dunning_campaign.id)
            end
          end

          it "stops and resets counters on customers" do
            customer = create(:customer, organization:, last_dunning_campaign_attempt: 1, last_dunning_campaign_attempt_at: Time.current)

            expect { result }.to change { customer.reload.last_dunning_campaign_attempt }.from(1).to(0)
              .and change { customer.last_dunning_campaign_attempt_at }.from(a_value).to(nil)
          end

          it "resets last attempt" do
            customer = create(
              :customer,
              organization:,
              last_dunning_campaign_attempt: 3,
              last_dunning_campaign_attempt_at: Time.zone.now
            )

            expect { result && customer.reload }
              .to change(customer, :last_dunning_campaign_attempt).to(0)
              .and change(customer, :last_dunning_campaign_attempt_at).to(nil)
          end
        end

        context "with no dunning campaign record" do
          let(:dunning_campaign) { nil }
          let(:thresholds_input) { nil }

          it "returns a failure" do
            expect(result).not_to be_success
            expect(result.error).to be_a(BaseService::NotFoundFailure)
            expect(result.error.message).to eq("dunning_campaign_not_found")
          end
        end
      end
    end
  end
end
