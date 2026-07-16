# frozen_string_literal: true

# rubocop:disable Rails/Output
Rails.application.console do
  if Rails.env.development?
    def gavin
      @gavin ||= hooli.users.find_by email: "gavin@hooli.com"
    end

    def hooli
      @hooli ||= Organization.find_by name: "Hooli"
    end

    def delete_hooli_webhooks
      hooli.webhook_endpoints.map do |endpoint|
        endpoint.webhooks.delete_all
      end.sum
    end
  end

  def find(id)
    model = if /^gid/.match?(id)
      GlobalID::Locator.locate(id)
    elsif Regex::EMAIL.match?(id)
      User.find_by email: id
    else
      raise "Don't know how to resolve this ¯\\_(ツ)_/¯. Please provide a valid email or Global ID."
    end
    puts "Organization: #{model.organization&.name}"
    model
  end

  def retry_generating_invoice(invoice)
    Invoices::SubscriptionService.new(
      subscriptions: invoice.subscriptions,
      timestamp: invoice.invoice_subscriptions.first.timestamp,
      invoicing_reason: :subscription_periodic,
      invoice: invoice,
      skip_charges: invoice.skip_charges
    ).call
  end

  def deadjobs_summary
    Sidekiq::DeadSet.new.map { it.args[0]["job_class"] }.tally
  end

  def enable_premium_integration!(org_id, integration_name)
    org = Organization.find(org_id)
    if org.premium_integrations.exclude?(integration_name)
      org.premium_integrations << integration_name
      org.save!
    end
    org.reload.premium_integrations
  end

  def current_usage(subscription, apply_taxes: false, with_cache: false, **kwargs)
    Invoices::CustomerUsageService.call!(
      customer: subscription.customer,
      subscription: subscription,
      apply_taxes:,
      with_cache:,
      **kwargs
    ).usage
  end

  def enable_all_premium_integrations!(org_id)
    org = Organization.find(org_id)
    org.update! premium_integrations: Organization::PREMIUM_INTEGRATIONS
    org.reload.premium_integrations
  end

  def hard_delete_invoice(id)
    invoice = Invoice.find(id)
    puts "Going to hard delete invoice from org `#{invoice.organization.name}` (id: #{invoice.id})"

    puts "Press any key to confirm deletion or CTRL+C to cancel."
    c = $stdin.getch

    if c == "\u0003"
      puts "Deletion cancelled."
      return invoice
    end

    puts "Deleting invoice #{invoice.id}..."
    ActiveRecord::Base.transaction do
      invoice.invoice_subscriptions.destroy_all
      invoice.credit_notes.destroy_all
      invoice.fees.each { |f| f.true_up_fee&.destroy! }
      invoice.fees.destroy_all
      invoice.taxes.destroy_all
      invoice.credits.destroy_all
      invoice.applied_invoice_custom_sections.destroy_all
      invoice.payments.destroy_all
      invoice.destroy!
    end

    begin
      invoice.reload
      puts "Invoice #{id} could not be deleted. Please try again."
    rescue ActiveRecord::RecordNotFound
      puts "Invoice #{id} has been successfully deleted."
    end
  end

  def create_organization(org_name:, email:)
    organization = Organizations::CreateService
      .call!(name: org_name, document_numbering: "per_organization")
      .organization

    result = Invites::CreateService.call(
      current_organization: organization,
      email: email,
      roles: %w[admin],
      skip_admin_check: true
    )

    puts "Organization `#{org_name}` created with admin invite: #{result.invite_url}"
    {organization:, invite_url: result.invite_url}
  end

  # Often this procedure is called "regenerate invoice"
  def delete_invoice_pdf(id)
    inv = Invoice.find(id)
    puts "Going to delete invoice pdf from org `#{inv.organization.name}` (id: #{inv.id})"
    unless inv.finalized?
      puts "Invoice is not finalized. Skipping."
      return
    end

    inv.file&.destroy
  end

  def check_stripe_payment(invoice_id)
    invoice = Invoice.unscoped.find(invoice_id)
    payments = invoice.payments.includes(:payment_provider).order(:created_at)

    puts "Invoice #{invoice.id}  total=#{invoice.total_amount_cents} due=#{invoice.total_due_amount_cents} #{invoice.currency}"
    puts ""

    payments.each do |payment|
      puts "Lago Payment #{payment.id}: #{payment.amount_cents} #{payment.amount_currency} status=#{payment.status} payable_status=#{payment.payable_payment_status || "-"} pi=#{payment.provider_payment_id || "-"}"

      next unless payment.payment_provider.is_a?(PaymentProviders::StripeProvider) && payment.provider_payment_id.present?

      pi = ::Stripe::PaymentIntent.retrieve(
        payment.provider_payment_id,
        {api_key: payment.payment_provider.secret_key}
      )
      puts "Stripe PI #{pi.id}: #{pi.amount} #{pi.currency} status=#{pi.status}"
      if pi.last_payment_error
        puts "  last_payment_error: #{pi.last_payment_error.code} #{pi.last_payment_error.message}"
      end
      puts ""
    rescue ::Stripe::StripeError => e
      puts "  ! Stripe fetch failed: #{e.class} #{e.message}"
      puts ""
    end

    invoice
  end

  def find_dead_jobs_by_job_name_and_error(job_name, error_class)
    ds = Sidekiq::DeadSet.new

    ds.select do |job|
      job.item["wrapped"].include?(job_name) && job.item["error_class"] == error_class
    end
  end

  def clear_dead_termination_jobs
    jobs = find_dead_jobs_by_job_name_and_error("BillSubscriptionJob", "RecordNotUnique")
    # Count the number of filtered jobs
    puts "Total BillSubscription jobs with error_class 'RecordNotUnique': #{jobs.count}"

    to_be_deleted = 0
    not_terminated = 0
    no_invoice = 0

    # Iterate over the jobs
    jobs.each do |job|
      job_args = job.item["args"].first["arguments"]

      # Extract subscription ID from job arguments
      subscription_id = job_args[0][0]["_aj_globalid"].split("Subscription/").last
      invoicing_reason = job_args[2]["invoicing_reason"]["value"]
      invoicing_reason = :subscription_terminating if invoicing_reason == "upgrading"

      # Find the last invoice related to this subscription
      invoice = InvoiceSubscription.where(invoicing_reason:, subscription_id:).order(:created_at).last&.invoice

      # Check if the invoice has been generated and get its status
      if invoice
        if (invoice.status == "closed" && invoice.fees_amount_cents.zero?) || invoice.status == "finalized"
          subscription = Subscription.find(subscription_id)
          if subscription.terminated?
            # Remove the dead job if everything seems correct
            job.delete
            to_be_deleted += 1
          else
            not_terminated += 1
          end
        else
          # puts "Subscription #{subscription_id} is not terminated. Keeping job in dead set."
          not_terminated += 1
        end
      else
        # puts "No invoice found for Subscription #{subscription_id}. Keeping job in dead set."
        no_invoice += 1
      end
    end

    puts "Summary:"
    puts "Jobs to be deleted: " + to_be_deleted.to_s
    puts "Subscriptions not terminated: " + not_terminated.to_s
    puts "Subscriptions with no invoice: " + no_invoice.to_s
  end
end
# rubocop:enable Rails/Output
