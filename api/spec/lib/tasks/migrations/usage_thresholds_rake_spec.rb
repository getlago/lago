# frozen_string_literal: true

require "rails_helper"

require "rake"

RSpec.describe "migrations:migrate_usage_thresholds" do # rubocop:disable RSpec/DescribeClass
  let(:task) { Rake::Task["migrations:migrate_usage_thresholds"] }

  let(:organization) { create(:organization) }
  let(:feature) { create(:feature, organization:) }
  let(:parent_plan) { create(:plan, organization:) }
  let(:child_plan) { create(:plan, organization:, parent: parent_plan) }
  let(:customer) { create(:customer, organization:) }
  let(:subscription) { create(:subscription, organization:, plan: child_plan, customer:) }

  before do
    Rake.application.rake_require("tasks/migrations/usage_thresholds")
    Rake::Task.define_task(:environment)
    task.reenable
  end

  context "without an organization_id argument" do
    it "aborts with a usage message" do
      expect { task.invoke }.to raise_error(SystemExit).and output(/Missing organization_id argument/).to_stderr
    end
  end

  context "when child plan thresholds match the parent plan thresholds" do
    let!(:parent_threshold) do
      create(:usage_threshold, plan: parent_plan, organization:, amount_cents: 1000, recurring: false)
    end

    let!(:child_threshold) do
      create(:usage_threshold, plan: child_plan, organization:, amount_cents: 1000, recurring: false)
    end

    before { subscription }

    it "soft-deletes the child plan thresholds" do
      expect { task.invoke(organization.id) }.to output(/Done/).to_stdout

      expect(child_threshold.reload.deleted_at).not_to be_nil
      expect(parent_threshold.reload.deleted_at).to be_nil
    end

    it "does not create any subscription thresholds" do
      expect { task.invoke(organization.id) }.to output(/Migrated 1 subscription/).to_stdout

      expect(subscription.reload.usage_thresholds).to be_empty
    end
  end

  context "when child plan thresholds differ from the parent plan thresholds" do
    let!(:parent_threshold) do # rubocop:disable RSpec/LetSetup
      create(:usage_threshold, plan: parent_plan, organization:, amount_cents: 1000, recurring: false)
    end

    let!(:child_threshold) do
      create(:usage_threshold, plan: child_plan, organization:, amount_cents: 2000, recurring: false)
    end

    before { subscription }

    it "copies the child plan thresholds to each subscription" do
      expect { task.invoke(organization.id) }.to output(/Done/).to_stdout

      sub_thresholds = subscription.reload.usage_thresholds
      expect(sub_thresholds.size).to eq(1)
      expect(sub_thresholds.first).to have_attributes(
        amount_cents: 2000,
        recurring: false,
        organization_id: organization.id
      )
    end

    it "soft-deletes the child plan thresholds" do
      expect { task.invoke(organization.id) }.to output(/Done/).to_stdout

      expect(child_threshold.reload.deleted_at).not_to be_nil
    end
  end

  context "when child plan has multiple thresholds matching the parent" do
    before do
      create(:usage_threshold, plan: parent_plan, organization:, amount_cents: 1000, recurring: false)
      create(:usage_threshold, :recurring, plan: parent_plan, organization:, amount_cents: 500)
      create(:usage_threshold, plan: child_plan, organization:, amount_cents: 1000, recurring: false)
      create(:usage_threshold, :recurring, plan: child_plan, organization:, amount_cents: 500)
      subscription
    end

    it "soft-deletes all child plan thresholds" do
      task.invoke(organization.id)
      expect(child_plan.usage_thresholds.unscoped.where.not(deleted_at: nil).count).to eq(2)
    end
  end

  context "when child plan has multiple thresholds differing from the parent" do
    before do
      create(:usage_threshold, plan: parent_plan, organization:, amount_cents: 1000, recurring: false)
      create(:usage_threshold, plan: child_plan, organization:, amount_cents: 2000, recurring: false)
      create(:usage_threshold, :recurring, plan: child_plan, organization:, amount_cents: 3000)
      subscription
    end

    it "copies all child thresholds to the subscription" do
      expect { task.invoke(organization.id) }.to output(/Done/).to_stdout

      sub_thresholds = subscription.reload.usage_thresholds
      expect(sub_thresholds.map { |t| [t.amount_cents, t.recurring] }).to match_array(
        [[2000, false], [3000, true]]
      )
    end
  end

  context "when child plan has no usage thresholds but parent does" do
    before do
      create(:usage_threshold, plan: parent_plan, organization:, amount_cents: 1000, recurring: false)
      subscription
    end

    it "sets progressive_billing_disabled on the subscription" do
      expect { task.invoke(organization.id) }.to output(/Migrated 1 subscription/).to_stdout

      expect(subscription.reload.progressive_billing_disabled).to be(true)
    end

    it "does not create any subscription thresholds" do
      task.invoke(organization.id)

      expect(subscription.reload.usage_thresholds).to be_empty
    end
  end

  context "when child plan has no usage thresholds and parent also has none" do
    before { subscription }

    it "does not set progressive_billing_disabled" do
      expect { task.invoke(organization.id) }.to output(/Migrated 0 subscription/).to_stdout

      expect(subscription.reload.progressive_billing_disabled).to be(false)
    end
  end

  context "when parent plan has no usage thresholds but child does" do
    let!(:child_threshold) do
      create(:usage_threshold, plan: child_plan, organization:, amount_cents: 500, recurring: false)
    end

    before { subscription }

    it "moves child thresholds to subscriptions since signatures differ" do
      expect { task.invoke(organization.id) }.to output(/Done/).to_stdout

      expect(subscription.reload.usage_thresholds.size).to eq(1)
      expect(child_threshold.reload.deleted_at).not_to be_nil
    end
  end

  context "when subscription already has its own thresholds" do
    let!(:parent_threshold) do # rubocop:disable RSpec/LetSetup
      create(:usage_threshold, plan: parent_plan, organization:, amount_cents: 1000, recurring: false)
    end

    let!(:child_threshold) do
      create(:usage_threshold, plan: child_plan, organization:, amount_cents: 2000, recurring: false)
    end

    let!(:existing_sub_threshold) do
      create(:usage_threshold, :for_subscription, subscription:, organization:, amount_cents: 5000, recurring: false)
    end

    it "skips the subscription and does not duplicate thresholds" do
      expect { task.invoke(organization.id) }.to output(/Done/).to_stdout

      sub_thresholds = subscription.reload.usage_thresholds
      expect(sub_thresholds.size).to eq(1)
      expect(sub_thresholds.first.id).to eq(existing_sub_threshold.id)
    end

    it "still soft-deletes the child plan thresholds" do
      expect { task.invoke(organization.id) }.to output(/Done/).to_stdout

      expect(child_threshold.reload.deleted_at).not_to be_nil
    end
  end

  context "when thresholds on child plan are already soft-deleted" do
    before do
      create(:usage_threshold, plan: parent_plan, organization:, amount_cents: 1000, recurring: false)
      threshold = create(:usage_threshold, plan: child_plan, organization:, amount_cents: 2000, recurring: false)
      threshold.discard!
      subscription
    end

    it "sets progressive_billing_disabled since child plan has no visible thresholds" do
      expect { task.invoke(organization.id) }.to output(/Done. Migrated 1 subscription./).to_stdout

      expect(subscription.reload.progressive_billing_disabled).to be(true)
    end
  end

  context "with a different organization" do
    let(:other_organization) { create(:organization) }
    let(:other_feature) { create(:feature, organization: other_organization) }
    let(:other_parent_plan) { create(:plan, organization: other_organization) }
    let(:other_child_plan) { create(:plan, organization: other_organization, parent: other_parent_plan) }

    let!(:other_child_threshold) do
      create(:usage_threshold, plan: other_child_plan, organization: other_organization, amount_cents: 2000, recurring: false)
    end

    before do
      create(:usage_threshold, plan: other_parent_plan, organization: other_organization, amount_cents: 1000, recurring: false)
      create(:subscription, organization: other_organization, plan: other_child_plan)
    end

    it "does not affect thresholds from other organizations" do
      expect { task.invoke(organization.id) }.to output(/Done/).to_stdout

      expect(other_child_threshold.reload.deleted_at).to be_nil
    end
  end

  context "when the recurring flag differs between parent and child" do
    before do
      create(:usage_threshold, plan: parent_plan, organization:, amount_cents: 1000, recurring: false)
      create(:usage_threshold, :recurring, plan: child_plan, organization:, amount_cents: 1000)
      subscription
    end

    it "treats them as different signatures and moves to subscription" do
      expect { task.invoke(organization.id) }.to output(/Done/).to_stdout

      sub_thresholds = subscription.reload.usage_thresholds
      expect(sub_thresholds.size).to eq(1)
      expect(sub_thresholds.first).to have_attributes(amount_cents: 1000, recurring: true)
    end
  end

  context "when threshold_display_name is preserved" do
    let!(:child_threshold) do # rubocop:disable RSpec/LetSetup
      create(:usage_threshold, plan: child_plan, organization:, amount_cents: 2000, recurring: false, threshold_display_name: "Custom Name")
    end

    before do
      create(:usage_threshold, plan: parent_plan, organization:, amount_cents: 1000, recurring: false)
      subscription
    end

    it "copies the threshold_display_name to the subscription threshold" do
      expect { task.invoke(organization.id) }.to output(/Done/).to_stdout

      sub_threshold = subscription.reload.usage_thresholds.first
      expect(sub_threshold.threshold_display_name).to eq("Custom Name")
    end
  end

  context "with multiple child plans under the same parent" do
    let(:child_plan2) { create(:plan, organization:, parent: parent_plan) }
    let(:customer2) { create(:customer, organization:) }
    let!(:subscription2) { create(:subscription, organization:, plan: child_plan2, customer: customer2) }

    before do
      create(:usage_threshold, plan: parent_plan, organization:, amount_cents: 1000, recurring: false)
      # child_plan has matching thresholds
      create(:usage_threshold, plan: child_plan, organization:, amount_cents: 1000, recurring: false)
      # child_plan2 has different thresholds
      create(:usage_threshold, plan: child_plan2, organization:, amount_cents: 3000, recurring: false)
      subscription
    end

    it "deletes matching child plan thresholds and moves differing ones" do
      expect { task.invoke(organization.id) }.to output(/Done/).to_stdout

      expect(child_plan.usage_thresholds).to be_empty
      expect(child_plan2.usage_thresholds).to be_empty
      expect(subscription.reload.usage_thresholds).to be_empty
      expect(subscription2.reload.usage_thresholds.size).to eq(1)
      expect(subscription2.usage_thresholds.first.amount_cents).to eq(3000)
    end
  end

  context "with multiple child plans where one has no thresholds" do
    let(:child_plan2) { create(:plan, organization:, parent: parent_plan) }
    let(:child_plan3) { create(:plan, organization:, parent: parent_plan) }
    let(:customer2) { create(:customer, organization:) }
    let(:customer3) { create(:customer, organization:) }
    let!(:subscription2) { create(:subscription, organization:, plan: child_plan2, customer: customer2) }
    let!(:subscription3) { create(:subscription, organization:, plan: child_plan3, customer: customer3) }

    before do
      create(:usage_threshold, plan: parent_plan, organization:, amount_cents: 1000, recurring: false)
      # child_plan has matching thresholds
      create(:usage_threshold, plan: child_plan, organization:, amount_cents: 1000, recurring: false)
      # child_plan2 has different thresholds
      create(:usage_threshold, plan: child_plan2, organization:, amount_cents: 2000, recurring: false)
      # child_plan3 has NO thresholds
      subscription
    end

    it "handles each subscription appropriately" do
      expect { task.invoke(organization.id) }.to output(/Done/).to_stdout

      # child_plan matching → soft-deleted, no subscription thresholds
      expect(child_plan.usage_thresholds).to be_empty
      expect(subscription.reload.usage_thresholds).to be_empty
      expect(subscription.progressive_billing_disabled).to be(false)

      # child_plan2 differing → moved to subscription, soft-deleted
      expect(child_plan2.usage_thresholds).to be_empty
      expect(subscription2.reload.usage_thresholds.size).to eq(1)
      expect(subscription2.progressive_billing_disabled).to be(false)

      # child_plan3 empty → progressive_billing_disabled set
      expect(subscription3.reload.usage_thresholds).to be_empty
      expect(subscription3.progressive_billing_disabled).to be(true)
    end
  end

  context "when subscription already has progressive_billing_disabled set" do
    before do
      create(:usage_threshold, plan: parent_plan, organization:, amount_cents: 1000, recurring: false)
      subscription.update!(progressive_billing_disabled: true)
    end

    it "keeps progressive_billing_disabled as true" do
      expect { task.invoke(organization.id) }.to output(/Migrated 1 subscription/).to_stdout

      expect(subscription.reload.progressive_billing_disabled).to be(true)
    end
  end
end
