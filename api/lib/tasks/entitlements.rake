# frozen_string_literal: true

namespace :entitlements do
  desc "Count duplicate subscription entitlements that would be cleaned up"
  task :count_duplicate_subscription_entitlements, [:organization_id] => :environment do |_task, args|
    organization_id = args[:organization_id]
    abort "Missing organization_id argument\n\nUsage: rake entitlements:count_duplicate_subscription_entitlements[organization_id]" unless organization_id

    count_sql = <<~SQL.squish
      SELECT COUNT(*)
      FROM entitlement_entitlements sub_ent
      JOIN subscriptions s ON s.id = sub_ent.subscription_id
      JOIN plans p ON p.id = s.plan_id
      JOIN entitlement_entitlements plan_ent
        ON plan_ent.entitlement_feature_id = sub_ent.entitlement_feature_id
        AND plan_ent.plan_id = COALESCE(p.parent_id, p.id)
        AND plan_ent.deleted_at IS NULL
      WHERE sub_ent.subscription_id IS NOT NULL
        AND sub_ent.deleted_at IS NULL
        AND sub_ent.organization_id = $1
        AND NOT EXISTS (
          SELECT 1 FROM entitlement_entitlement_values v
          WHERE v.entitlement_entitlement_id = sub_ent.id
            AND v.deleted_at IS NULL
        )
    SQL

    count = ActiveRecord::Base.connection.select_value(count_sql, "Count duplicate entitlements", [organization_id])
    puts "Found #{count} duplicate subscription entitlements for organization #{organization_id}."
  end

  desc "Soft-delete duplicate subscription entitlements that have no values and whose feature is already on the parent plan"
  task :cleanup_duplicate_subscription_entitlements, [:organization_id] => :environment do |_task, args|
    organization_id = args[:organization_id]
    abort "Missing organization_id argument\n\nUsage: rake entitlements:cleanup_duplicate_subscription_entitlements[organization_id]" unless organization_id

    read_batch_size = 1_000
    write_batch_size = 5000
    deleted_at = Time.current.beginning_of_hour
    total_deleted = 0
    last_id = nil

    puts "Starting cleanup of duplicate subscription entitlements for organization #{organization_id} (deleted_at: #{deleted_at})..."

    loop do
      # Step 1: Get entitlements attached to subscriptions that are not soft deleted.
      # Uses ID-based cursor pagination to ensure progress through the dataset.
      scope = Entitlement::Entitlement
        .where(organization_id: organization_id)
        .where.not(subscription_id: nil)
        .order(:id)
        .limit(read_batch_size)
      scope = scope.where("id > ?", last_id) if last_id

      subscription_entitlements = scope.to_a
      break if subscription_entitlements.empty?

      last_id = subscription_entitlements.last.id

      # Step 2: Check which entitlements have values and exclude them from processing.
      entitlement_ids = subscription_entitlements.map(&:id)
      entitlements_with_values_ids = Entitlement::EntitlementValue
        .where(entitlement_entitlement_id: entitlement_ids)
        .distinct
        .pluck(:entitlement_entitlement_id)
        .to_set

      subscription_entitlements.reject! { |e| entitlements_with_values_ids.include?(e.id) }
      next if subscription_entitlements.empty?

      # Step 3: For each subscription in the batch, resolve the effective plan
      # (parent plan if it exists, otherwise the subscription's own plan).
      subscription_ids = subscription_entitlements.map(&:subscription_id).uniq
      subscription_to_plan = Subscription
        .joins(:plan)
        .where(id: subscription_ids)
        .pluck(:id, Arel.sql("COALESCE(plans.parent_id, plans.id)"))
        .to_h

      # Step 4: Get all feature IDs attached to these plans and build a lookup hash
      # mapping each subscription_id to its plan's feature IDs.
      plan_ids = subscription_to_plan.values.uniq
      plan_to_features = Hash.new { |h, k| h[k] = Set.new }
      Entitlement::Entitlement
        .where(plan_id: plan_ids)
        .pluck(:plan_id, :entitlement_feature_id)
        .each { |plan_id, feature_id| plan_to_features[plan_id].add(feature_id) }

      subscription_to_plan_feature_ids = subscription_to_plan.transform_values { |plan_id| plan_to_features[plan_id] }

      # Step 5: Soft-delete subscription entitlements whose feature is already on the plan.
      ids_to_delete = subscription_entitlements
        .select { |e| subscription_to_plan_feature_ids[e.subscription_id]&.include?(e.entitlement_feature_id) }
        .map(&:id)

      next if ids_to_delete.empty?

      ids_to_delete.each_slice(write_batch_size) do |batch_ids|
        deleted_count = Entitlement::Entitlement
          .where(id: batch_ids)
          .update_all(deleted_at: deleted_at) # rubocop:disable Rails/SkipsModelValidations
        total_deleted += deleted_count
        puts "  Progress: #{total_deleted} entitlements soft-deleted..."
      end
    end

    puts "Done. Soft-deleted #{total_deleted} entitlements."
  end
end
