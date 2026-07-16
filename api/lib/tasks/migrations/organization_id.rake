# frozen_string_literal: true

namespace :migrations do
  desc "Populate organization_id on every tables"
  task fill_organization_id: :environment do
    Rails.logger.level = Logger::Severity::ERROR

    resources_to_fill = [
      {model: AddOn::AppliedTax, job: DatabaseMigrations::PopulateAddOnsTaxesWithOrganizationJob},
      {model: AdjustedFee, job: DatabaseMigrations::PopulateAdjustedFeesWithOrganizationJob},
      {model: AppliedCoupon, job: DatabaseMigrations::PopulateAppliedCouponsWithOrganizationJob},
      {model: AppliedInvoiceCustomSection, job: DatabaseMigrations::PopulateAppliedInvoiceCustomSectionsWithOrganizationJob},
      {model: AppliedUsageThreshold, job: DatabaseMigrations::PopulateAppliedUsageThresholdsWithOrganizationJob},
      {model: BillableMetricFilter, job: DatabaseMigrations::PopulateBillableMetricFiltersWithOrganizationJob},
      {model: BillingEntity::AppliedTax, job: DatabaseMigrations::PopulateBillingEntitiesTaxesWithOrganizationJob},
      {model: ChargeFilterValue, job: DatabaseMigrations::PopulateChargeFilterValuesWithOrganizationJob},
      {model: ChargeFilter, job: DatabaseMigrations::PopulateChargeFiltersWithOrganizationJob},
      {model: Charge::AppliedTax, job: DatabaseMigrations::PopulateChargesTaxesWithOrganizationJob},
      {model: Charge, job: DatabaseMigrations::PopulateChargesWithOrganizationJob},
      {model: Commitment::AppliedTax, job: DatabaseMigrations::PopulateCommitmentsTaxesWithOrganizationJob},
      {model: Commitment, job: DatabaseMigrations::PopulateCommitmentsWithOrganizationJob},
      {model: CouponTarget, job: DatabaseMigrations::PopulateCouponTargetsWithOrganizationJob},
      {model: CreditNoteItem, job: DatabaseMigrations::PopulateCreditNoteItemsWithOrganizationJob},
      {model: CreditNote::AppliedTax, job: DatabaseMigrations::PopulateCreditNotesTaxesWithOrganizationJob},
      {model: CreditNote, job: DatabaseMigrations::PopulateCreditNotesWithOrganizationJob},
      {model: Credit, job: DatabaseMigrations::PopulateCreditsWithOrganizationJob},
      {model: Metadata::CustomerMetadata, job: DatabaseMigrations::PopulateCustomerMetadataWithOrganizationJob},
      {model: Customer::AppliedTax, job: DatabaseMigrations::PopulateCustomersTaxesWithOrganizationJob},
      {model: DataExportPart, job: DatabaseMigrations::PopulateDataExportPartsWithOrganizationJob},
      {model: DunningCampaignThreshold, job: DatabaseMigrations::PopulateDunningCampaignThresholdsWithOrganizationJob},
      {model: Fee::AppliedTax, job: DatabaseMigrations::PopulateFeesTaxesWithOrganizationJob},
      {model: IdempotencyRecord, job: DatabaseMigrations::PopulateIdempotencyRecordsWithOrganizationJob},
      {model: IntegrationCollectionMappings::BaseCollectionMapping, job: DatabaseMigrations::PopulateIntegrationCollectionMappingsWithOrganizationJob},
      {model: IntegrationCustomers::BaseCustomer, job: DatabaseMigrations::PopulateIntegrationCustomersWithOrganizationJob},
      {model: IntegrationItem, job: DatabaseMigrations::PopulateIntegrationItemsWithOrganizationJob},
      {model: IntegrationMappings::BaseMapping, job: DatabaseMigrations::PopulateIntegrationMappingsWithOrganizationJob},
      {model: IntegrationResource, job: DatabaseMigrations::PopulateIntegrationResourcesWithOrganizationJob},
      {model: Metadata::InvoiceMetadata, job: DatabaseMigrations::PopulateInvoiceMetadataWithOrganizationJob},
      {model: InvoiceSubscription, job: DatabaseMigrations::PopulateInvoiceSubscriptionsWithOrganizationJob},
      {model: PaymentRequest::AppliedInvoice, job: DatabaseMigrations::PopulateInvoicesPaymentRequestsWithOrganizationJob},
      {model: Invoice::AppliedTax, job: DatabaseMigrations::PopulateInvoicesTaxesWithOrganizationJob},
      {model: PaymentProviderCustomers::BaseCustomer, job: DatabaseMigrations::PopulatePaymentProviderCustomersWithOrganizationJob},
      {model: Payment, job: DatabaseMigrations::PopulatePaymentsWithOrganizationFromInvoiceJob},
      {model: Payment, job: DatabaseMigrations::PopulatePaymentsWithOrganizationFromPaymentRequestJob},
      {model: Plan::AppliedTax, job: DatabaseMigrations::PopulatePlansTaxesWithOrganizationJob},
      {model: RecurringTransactionRule, job: DatabaseMigrations::PopulateRecurringTransactionRulesWithOrganizationJob},
      {model: Refund, job: DatabaseMigrations::PopulateRefundsWithOrganizationJob},
      {model: Subscription, job: DatabaseMigrations::PopulateSubscriptionsWithOrganizationJob},
      {model: UsageThreshold, job: DatabaseMigrations::PopulateUsageThresholdsWithOrganizationJob},
      {model: WalletTransaction, job: DatabaseMigrations::PopulateWalletTransactionsWithOrganizationJob},
      {model: Wallet, job: DatabaseMigrations::PopulateWalletsWithOrganizationJob},
      {model: Webhook, job: DatabaseMigrations::PopulateWebhooksWithOrganizationJob}
    ]

    puts "##################################\nStarting filling organization_id"
    puts "\n#### Checking for resource to fill ####"

    to_fill = []

    resources_to_fill.each do |resource|
      model = resource[:model]
      pp "- Checking #{model.name}: 🔎"
      count = model.where(organization_id: nil).count

      if count > 0
        to_fill << resource
        pp "  -> #{count} records to fill 🧮"
      else
        pp "  -> Nothing to do ✅"
      end
    end

    if to_fill.any?
      puts "\n#### Enqueue jobs in the low_priority queue ####"
      to_fill.each do |resource|
        pp "- Enqueuing #{resource[:job].name}"
        resource[:job].perform_later
      end
    end

    while to_fill.present?
      sleep 5
      puts "\n#### Checking status ####"

      to_delete = []
      to_fill.each do |resource|
        model = resource[:model]
        pp "- Checking #{model.name}: 🔎"
        count = model.where(organization_id: nil).count

        if count > 0
          pp "  -> #{count} remaining 🧮"
        else
          to_delete << resource
          pp "  -> Done ✅"
        end
      end

      to_delete.each { to_fill.delete(it) }
    end

    puts "\n#### All good, ready to Upgrade! ✅ ####"
  end
end
