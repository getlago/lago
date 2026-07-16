# frozen_string_literal: true

namespace :migrations do
  desc "Migrate usage thresholds from child plans to subscriptions or remove duplicates"
  task :migrate_usage_thresholds, [:organization_id] => :environment do |_task, args|
    organization_id = args[:organization_id]
    abort "Missing organization_id argument\n\nUsage: rake migrations:migrate_usage_thresholds[organization_id]" unless organization_id

    organization = Organization.find(organization_id)

    threshold_signature = ->(thresholds) { thresholds.map { |t| [t.amount_cents, t.recurring] }.sort }

    parent_plans = organization.plans.parents

    total_sub_migrated = 0

    parent_plans.find_each do |parent_plan|
      parent_signature = threshold_signature.call(parent_plan.usage_thresholds)

      subscriptions = organization.subscriptions
        .joins(:plan)
        .where(plans: {parent_id: parent_plan.id})
        .where(status: [:pending, :active])
        .includes(plan: :usage_thresholds)

      puts "#{subscriptions.count} subscriptions to migrate"
      puts "\t Parent signature: #{parent_signature.to_json}"

      subscriptions.find_each do |subscription|
        child_plan = subscription.plan
        child_thresholds = child_plan.usage_thresholds.to_a

        if child_thresholds.empty?
          if parent_signature.present?
            subscription.update!(progressive_billing_disabled: true)
            total_sub_migrated += 1
          end
          next
        end

        child_signature = threshold_signature.call(child_thresholds)

        if child_signature == parent_signature
          child_plan.usage_thresholds.update_all(deleted_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
        else
          ActiveRecord::Base.transaction do
            if subscription.usage_thresholds.none?
              child_thresholds.each do |threshold|
                UsageThreshold.create!(
                  organization:,
                  subscription:,
                  amount_cents: threshold.amount_cents,
                  recurring: threshold.recurring,
                  threshold_display_name: threshold.threshold_display_name
                )
              end
            end

            child_plan.usage_thresholds.update_all(deleted_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
          end
        end

        total_sub_migrated += 1
      end
    end

    puts
    puts "Done. Migrated #{total_sub_migrated} subscription."
  end
end
