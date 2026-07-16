# frozen_string_literal: true

namespace :customers do
  desc "Generate Slug for Customers"
  task generate_slug: :environment do
    Customer.unscoped.order(:created_at).find_each(&:save)
  end

  # WARNING! Potentially dangerous task
  desc "Migrate customer to a new billing entity. This version is actual on August 2025, please, check before running if anything needs to be updated"
  task :migrate_to_new_entity, [:organization_id, :customer_external_id, :billing_entity_code] => :environment do |_task, args|
    customer_external_id = args[:customer_external_id]
    billing_entity_code = args[:billing_entity_code]

    cust = Customer.find_by(external_id: customer_external_id)
    new_be = cust.organization.billing_entities.find_by(code: billing_entity_code)

    # wallets are now implemented, but require a change in the codebase
    # taxes should be easy to implement, but current customers do not have taxes, so we're not getting into it
    raise "Taxes not implemented" if cust.taxes.any?
    # current customer do not have coupons. when implementing coupons, pay attention on currencies
    raise "Coupons not implemented" if cust.coupons.any?

    # triggered dunning_campaign can be not a problem if all payments and payment_requests are managed - to figure it out with the organization
    raise "Customer has dunning campaigns triggered" if cust.last_dunning_campaign_attempt != 0
    raise "Customer has dunning campaigns triggered" unless cust.last_dunning_campaign_attempt_at.nil?
    raise "Customer should not have payment requests" if cust.payment_requests.any?
    # pay_in_advance will immediately trigger the invoice, which is not a desired behaviour
    raise "customer has a subscription with a plan that is pay_in_advance" if cust.subscriptions.any? { |sub| sub.plan.pay_in_advance? }
    raise "Customer has an unknown integration customer" if cust.integration_customers.any? { |int_cust| int_cust.type != "IntegrationCustomers::AnrokCustomer" && int_cust.type != "IntegrationCustomers::NetsuiteCustomer" }
    # customers this script was created for, did not have credit_notes, metadata, invoice custom sections
    raise "Customer should not have any credit notes" if cust.credit_notes.any?
    raise "Metadata is not implemented" if cust.metadata.any?
    raise "Invoice custom sections are not implemented" if cust.applied_invoice_custom_sections.any?

    ActiveRecord::Base.transaction do
      cust.discard

      new_cust = cust.dup
      new_cust.billing_entity = new_be
      new_cust.deleted_at = nil
      new_cust.payment_receipt_counter = 0
      new_cust.sequential_id = nil
      new_cust.slug = nil
      new_cust.last_dunning_campaign_attempt = 0
      new_cust.last_dunning_campaign_attempt_at = nil
      new_cust.save!

      cust.subscriptions.active.each do |sub|
        puts "Terminating active subscription with id #{sub.id} for customer #{cust.id}"
        sub.update(on_termination_invoice: :skip)
        Subscriptions::TerminateService.call(subscription: sub, async: false)
      end

      cust.integration_customers.each do |int_cust|
        if int_cust.type == "IntegrationCustomers::AnrokCustomer"
          new_int_cust = int_cust.dup
          new_int_cust.customer = new_cust
          new_int_cust.save!
        elsif int_cust.type == "IntegrationCustomers::NetsuiteCustomer"
          # we decided that they will need to manually create new integration customers
        else
          raise "Unknown integration customer type: #{int_cust.type}"
        end
      end

      cust.payment_provider_customers.each do |payment_provider_cust|
        new_payment_provider_cust = payment_provider_cust.dup
        new_payment_provider_cust.customer = new_cust
        new_payment_provider_cust.save!
      end

      # do we want to create wallet with 0 values, and create an inbound transaction of granted credits???
      cust.wallets.each do |wallet|
        wallet_params = {
          organization_id: new_cust.organization_id,
          customer: new_cust,
          name: wallet.name,
          rate_amount: wallet.rate_amount,
          currency: wallet.currency,
          expiration_at: wallet.expiration_at,
          invoice_requires_successful_payment: wallet.invoice_requires_successful_payment,
          applies_to: {
            fee_types: wallet.allowed_fee_types
          },
          granted_credits: wallet.credits_balance.to_s
        }
        new_wallet = Wallets::CreateService.call!(params: wallet_params).wallet

        wallet.recurring_transaction_rules.each do |rule|
          new_rule = rule.dup
          new_rule.wallet = new_wallet
          new_rule.save!
        end
        wallet.wallet_targets.each do |target|
          new_target = target.dup
          new_target.wallet = new_wallet
          new_target.save!
        end
      end

      Customers::TerminateRelationsService.call(customer: cust)
    end
  end

  desc "Backfill EU auto-taxes for customers whose applied lago_eu_XX_standard no longer matches customers.country"
  task :backfill_eu_auto_taxes, [:organization_id] => :environment do |_task, args|
    organization_id = args[:organization_id]
    abort "Missing organization_id argument\n\nUsage: rake customers:backfill_eu_auto_taxes[organization_id]" if organization_id.blank?

    batch_size = (ENV["BATCH_SIZE"] || 500).to_i
    abort "BATCH_SIZE must be positive" if batch_size <= 0

    dry_run = ENV.fetch("DRY_RUN", "true") != "false"
    mode = dry_run ? "DRY RUN" : "LIVE"

    total_processed = 0
    counters = {reapply: 0, vies_pending: 0, skipped: 0}

    puts "Starting EU auto-taxes backfill [#{mode}] for organization #{organization_id} (batch_size: #{batch_size})..."

    preview_customer = lambda do |customer|
      result = nil
      ActiveRecord::Base.transaction(requires_new: true) do
        result = Customers::EuAutoTaxesService.call(
          customer: customer,
          new_record: false,
          tax_attributes_changed: true
        )
        raise ActiveRecord::Rollback
      end

      current_eu_codes = customer.taxes.where("code ILIKE ?", "lago_eu%").pluck(:code)

      if result.success?
        counters[:reapply] += 1
        puts "  [DRY RUN] customer=#{customer.id} country=#{customer.country} current_eu=#{current_eu_codes.inspect} -> target=#{result.tax_code} (would re-apply)"
      elsif result.error.is_a?(BaseService::ServiceFailure) && result.error.code == "vies_check_pending"
        counters[:vies_pending] += 1
        puts "  [DRY RUN] customer=#{customer.id} country=#{customer.country} current_eu=#{current_eu_codes.inspect} would schedule VIES check"
      else
        code = result.error.respond_to?(:code) ? result.error.code : "unknown"
        counters[:skipped] += 1
        puts "  [DRY RUN] customer=#{customer.id} country=#{customer.country} current_eu=#{current_eu_codes.inspect} skipped (#{code})"
      end
    end

    scope = Customer
      .joins(applied_taxes: :tax)
      .joins(:billing_entity)
      .where(customers: {organization_id: organization_id})
      .where(billing_entities: {eu_tax_management: true})
      .where.not(customers: {country: nil})
      .where("taxes.code ~ '^lago_eu_[a-z]{2}_standard$'")
      .where("taxes.code <> CONCAT('lago_eu_', LOWER(customers.country), '_standard')")
      .where("NOT EXISTS (SELECT 1 FROM pending_vies_checks pvc WHERE pvc.customer_id = customers.id)")
      .distinct

    if dry_run
      candidate_ids = scope.pluck(:id)
      puts "  Candidates found: #{candidate_ids.size}"

      candidate_ids.each_slice(batch_size) do |ids|
        Customer.where(id: ids).find_each(&preview_customer)

        total_processed += ids.size
        puts "  Batch processed: #{ids.size} customers (total: #{total_processed})"
      end
    else
      loop do
        customer_ids = scope.limit(batch_size).pluck(:id)
        break if customer_ids.empty?

        Customer.where(id: customer_ids).find_each do |customer|
          result = Customers::EuAutoTaxesService.call(
            customer: customer,
            new_record: false,
            tax_attributes_changed: true
          )
          next unless result.success?

          preserved_codes = customer.taxes.where.not("code ILIKE 'lago_eu%'").pluck(:code)
          tax_codes = (preserved_codes + [result.tax_code]).uniq

          Customers::ApplyTaxesService.call!(customer: customer, tax_codes: tax_codes)
        end

        total_processed += customer_ids.size
        puts "  Batch processed: #{customer_ids.size} customers (total: #{total_processed})"
        break if customer_ids.size < batch_size
      end
    end

    puts "Done [#{mode}]. Total processed: #{total_processed}."
    if dry_run
      puts "  Would re-apply: #{counters[:reapply]}"
      puts "  Would schedule VIES check: #{counters[:vies_pending]}"
      puts "  Would skip: #{counters[:skipped]}"
    end
  end
end

