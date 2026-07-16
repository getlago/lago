# frozen_string_literal: true

require "rails_helper"

require "rake"

RSpec.describe "entitlements:cleanup_duplicate_subscription_entitlements" do # rubocop:disable RSpec/DescribeClass
  let(:task) { Rake::Task["entitlements:cleanup_duplicate_subscription_entitlements"] }

  let(:organization) { create(:organization) }
  let(:feature) { create(:feature, organization:) }
  let(:privilege) { create(:privilege, feature:, organization:) }
  let(:parent_plan) { create(:plan, organization:) }
  let(:child_plan) { create(:plan, organization:, parent: parent_plan) }
  let(:subscription) { create(:subscription, organization:, plan: child_plan) }

  let(:plan_entitlement) do
    create(:entitlement, feature:, plan: parent_plan, organization:)
  end

  before do
    plan_entitlement
    Rake.application.rake_require("tasks/entitlements")
    Rake::Task.define_task(:environment)
    task.reenable
  end

  context "with a duplicate subscription entitlement (no values, feature on plan)" do
    let!(:duplicate_entitlement) do
      create(:entitlement, :subscription, feature:, subscription:, organization:)
    end

    it "soft-deletes the duplicate entitlement with a rounded timestamp" do
      freeze_time do
        expected_deleted_at = Time.current.beginning_of_hour

        expect { task.invoke(organization.id) }.to output(/Done/).to_stdout

        expect(duplicate_entitlement.reload.deleted_at).to eq(expected_deleted_at)
      end
    end
  end

  context "with a subscription entitlement that has values" do
    let!(:entitlement_with_values) do
      entitlement = create(:entitlement, :subscription, feature:, subscription:, organization:)
      create(:entitlement_value, entitlement:, privilege:, organization:)
      entitlement
    end

    it "does not soft-delete entitlements that have values" do
      expect { task.invoke(organization.id) }.to output(/Soft-deleted 0 entitlements/).to_stdout

      expect(entitlement_with_values.reload.deleted_at).to be_nil
    end
  end

  context "with a subscription entitlement whose feature is not on the plan" do
    let(:other_feature) { create(:feature, organization:) }

    let!(:unique_entitlement) do
      create(:entitlement, :subscription, feature: other_feature, subscription:, organization:)
    end

    it "does not soft-delete entitlements for features not on the plan" do
      expect { task.invoke(organization.id) }.to output(/Soft-deleted 0 entitlements/).to_stdout

      expect(unique_entitlement.reload.deleted_at).to be_nil
    end
  end

  context "with a subscription on a plan without a parent" do
    let(:standalone_plan) { create(:plan, organization:) }
    let(:standalone_subscription) { create(:subscription, organization:, plan: standalone_plan) }

    let!(:duplicate_on_standalone) do
      create(:entitlement, :subscription, feature:, subscription: standalone_subscription, organization:)
    end

    before do
      create(:entitlement, feature:, plan: standalone_plan, organization:)
    end

    it "soft-deletes duplicates using COALESCE(parent_id, plan_id)" do
      freeze_time do
        expect { task.invoke(organization.id) }.to output(/Done/).to_stdout

        expect(duplicate_on_standalone.reload.deleted_at).to eq(Time.current.beginning_of_hour)
      end
    end
  end

  context "with mixed features on the same subscription (one duplicate, one unique)" do
    let(:unique_feature) { create(:feature, organization:) }

    let!(:duplicate_entitlement) do
      create(:entitlement, :subscription, feature:, subscription:, organization:)
    end

    let!(:unique_entitlement) do
      create(:entitlement, :subscription, feature: unique_feature, subscription:, organization:)
    end

    it "only soft-deletes the duplicate and preserves the unique one" do
      freeze_time do
        expect { task.invoke(organization.id) }.to output(/Done/).to_stdout

        expect(duplicate_entitlement.reload.deleted_at).to eq(Time.current.beginning_of_hour)
        expect(unique_entitlement.reload.deleted_at).to be_nil
      end
    end
  end

  context "when the plan entitlement is already soft-deleted" do
    let!(:subscription_entitlement) do
      create(:entitlement, :subscription, feature:, subscription:, organization:)
    end

    before do
      plan_entitlement.discard!
    end

    it "does not soft-delete the subscription entitlement" do
      expect { task.invoke(organization.id) }.to output(/Soft-deleted 0 entitlements/).to_stdout

      expect(subscription_entitlement.reload.deleted_at).to be_nil
    end
  end

  context "when entitlement values are soft-deleted" do
    let!(:entitlement_with_discarded_values) do
      entitlement = create(:entitlement, :subscription, feature:, subscription:, organization:)
      value = create(:entitlement_value, entitlement:, privilege:, organization:)
      value.discard!
      entitlement
    end

    it "soft-deletes the entitlement since soft-deleted values do not count" do
      freeze_time do
        expect { task.invoke(organization.id) }.to output(/Done/).to_stdout

        expect(entitlement_with_discarded_values.reload.deleted_at).to eq(Time.current.beginning_of_hour)
      end
    end
  end

  context "without an organization_id argument" do
    it "aborts with a usage message" do
      expect { task.invoke }.to raise_error(SystemExit).and output(/Missing organization_id argument/).to_stderr
    end
  end

  context "with a duplicate in a different organization" do
    let(:other_organization) { create(:organization) }
    let(:other_feature) { create(:feature, organization: other_organization) }
    let(:other_plan) { create(:plan, organization: other_organization) }
    let(:other_subscription) { create(:subscription, organization: other_organization, plan: other_plan) }

    let!(:other_duplicate) do
      create(:entitlement, :subscription, feature: other_feature, subscription: other_subscription, organization: other_organization)
    end

    before do
      create(:entitlement, feature: other_feature, plan: other_plan, organization: other_organization)
    end

    it "does not soft-delete entitlements from other organizations" do
      expect { task.invoke(organization.id) }.to output(/Soft-deleted 0 entitlements/).to_stdout

      expect(other_duplicate.reload.deleted_at).to be_nil
    end
  end
end
