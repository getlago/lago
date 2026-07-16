# frozen_string_literal: true

module Plans
  class DestroyService < BaseService
    Result = BaseResult[:plan]

    def initialize(plan:)
      @plan = plan
      super
    end

    activity_loggable(
      action: "plan.deleted",
      record: -> { plan }
    )

    def call
      return result.not_found_failure!(resource: "plan") unless plan

      # NOTE: Terminate active subscriptions.
      plan.subscriptions.active.find_each do |subscription|
        Subscriptions::TerminateService.call(subscription:, async: false)
      end

      # NOTE: Cancel pending subscription to make sure they won't be activated.
      plan.subscriptions.pending.find_each(&:mark_as_canceled!)

      # NOTE: Finalize all draft invoices.
      invoices = Invoice.draft.joins(:plans).where(plans: {id: plan.id}).distinct
      invoices.find_each { |invoice| Invoices::RefreshDraftAndFinalizeService.call(invoice:) }

      # rubocop:disable Rails/SkipsModelValidations
      plan.entitlement_values.update_all(deleted_at: Time.current)
      plan.entitlements.update_all(deleted_at: Time.current)
      # rubocop:enable Rails/SkipsModelValidations

      plan.pending_deletion = false
      plan.discard!

      result.plan = plan
      result
    rescue Discard::RecordNotDiscarded
      @plan = Plan.with_discarded.find_by(id: plan.id)
      raise unless plan.discarded?

      result.plan = plan
      result
    end

    private

    attr_reader :plan
  end
end
