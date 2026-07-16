# frozen_string_literal: true

# Backfills `prepaid_granted_credit_amount_cents` and
# `prepaid_purchased_credit_amount_cents` on invoices finalized before the wallet
# credit breakdown feature shipped (https://github.com/getlago/lago-api/pull/5101).
#
# The heavy lifting is done by DatabaseMigrations::BackfillPrepaidCreditBreakdownJob,
# which processes invoices in batches on the low_priority queue and re-enqueues
# itself until everything in scope is filled. This rake only previews the work
# (DRY_RUN) or enqueues the job and polls until it drains.
#
# Prerequisite: `migrations:wallet_traceability` must have run for the wallets in
# scope. This task only fills invoices whose customer is fully traceable and that
# already have consumption rows to aggregate — exactly what the live code computes.
#
# Usage:
#   # 1. Preview for a single org (no writes):
#   lago exec api bundle exec rails migrations:backfill_prepaid_credit_breakdown \
#     DRY_RUN=true ORGANIZATION_ID=<uuid>
#
#   # 2. Apply for that org:
#   lago exec api bundle exec rails migrations:backfill_prepaid_credit_breakdown \
#     DRY_RUN=false ORGANIZATION_ID=<uuid>
#
#   # 3. Apply for everyone (drop ORGANIZATION_ID):
#   lago exec api bundle exec rails migrations:backfill_prepaid_credit_breakdown \
#     DRY_RUN=false
#
# Env:
#   DRY_RUN          "false" to enqueue the backfill. Default: true (report only).
#   ORGANIZATION_ID  Restrict to a single organization. Default: all.

namespace :migrations do
  desc "Backfill invoice prepaid credit breakdown columns (DRY_RUN=true by default)"
  task backfill_prepaid_credit_breakdown: :environment do
    Rails.logger.level = Logger::Severity::ERROR

    org_id = ENV["ORGANIZATION_ID"].presence
    dry_run = ENV.fetch("DRY_RUN", "true") != "false"
    job = DatabaseMigrations::BackfillPrepaidCreditBreakdownJob

    puts "##################################"
    puts "Prepaid credit breakdown backfill"
    puts "Organization: #{org_id || "all"}, mode: #{dry_run ? "DRY-RUN (report only)" : "BACKFILL (async)"}"
    puts "=" * 50

    pending = job.pending_count(org_id)

    if dry_run
      puts "Invoices that would be filled (computable, not set yet): #{pending}"
      puts "\nRun again with DRY_RUN=false to enqueue the backfill."
      next
    end

    if pending.zero?
      puts "Nothing to backfill ✅"
      next
    end

    puts "Enqueuing backfill for #{pending} invoice(s) on the low_priority queue..."
    job.perform_later(org_id)

    while pending.positive?
      sleep 5
      pending = job.pending_count(org_id)
      puts "  -> #{pending} remaining"
    end

    puts "\nDone ✅"
  end
end
