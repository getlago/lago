# frozen_string_literal: true

module Utils
  class ActivityLog
    IGNORED_FIELDS = %i[updated_at].freeze
    IGNORED_EXTERNAL_CUSTOMER_ID_CLASSES = %w[BillableMetric Coupon Plan BillingEntity Entitlement::Feature].freeze
    MAX_SERIALIZED_FEES = 25
    MAX_SERIALIZED_CHARGES = 50
    MAX_SERIALIZED_CHARGE_FILTERS = 100

    SERIALIZED_INCLUDED_OBJECTS = {
      billing_entity: %i[taxes],
      credit_note: %i[items applied_taxes error_details],
      customer: %i[taxes integration_customers applicable_invoice_custom_sections],
      invoice: %i[customer integration_customers billing_periods subscriptions fees credits metadata applied_taxes error_details applied_invoice_custom_sections],
      plan: %i[charges usage_thresholds taxes minimum_commitment],
      subscription: %i[plan],
      wallet: %i[recurring_transaction_rules]
    }.freeze

    def self.produce(*, **, &)
      new(*, **, &).produce
    end

    def self.available?
      ENV["LAGO_CLICKHOUSE_ENABLED"].present? &&
        ENV["LAGO_KAFKA_BOOTSTRAP_SERVERS"].present? &&
        ENV["LAGO_KAFKA_ACTIVITY_LOGS_TOPIC"].present?
    end

    # This method is used to produce an activity log after a commit.
    #
    # It is meant to avoid race-conditions where a asynchronous post-processing run before changes are commited to the DB.
    def self.produce_after_commit(object, activity_type, activity_id: nil, &)
      kwargs = {after_commit: true, activity_id:}.compact
      produce(object, activity_type, **kwargs, &)
    end

    def initialize(object, activity_type, activity_id: SecureRandom.uuid, after_commit: false, &block)
      @object = object
      @activity_type = activity_type
      @activity_id = activity_id
      @block = block
      @after_commit = after_commit
    end

    def produce
      return block.call if object.nil? && block

      changes = {}
      if block
        before_attrs = object_serialized
        result = block.call
        return result if result.failure?

        # NOTE: This will cause any unsaved changes to be lost. So if `object` is used in `result`, the service `result`
        #       will not contain the unsaved changes.
        object.reload
        after_attrs = object_serialized

        changes = before_attrs.each_with_object({}) do |(key, before), result|
          after = after_attrs[key]
          result[key] = [before, after] if before != after
        end
      end

      run_maybe_after_commit { produce_with_diff(changes) }

      block ? result : nil
    end

    private

    attr_reader :object, :activity_type, :activity_id, :block, :after_commit

    def run_maybe_after_commit(&block)
      if after_commit
        AfterCommitEverywhere.after_commit(&block)
      else
        yield
      end
    end

    def produce_with_diff(changes)
      return unless self.class.available?

      current_time = Time.current.iso8601[...-1]
      KafkaProducer.produce_async(
        topic: ENV["LAGO_KAFKA_ACTIVITY_LOGS_TOPIC"],
        key: "#{organization_id}--#{activity_id}",
        payload: {
          activity_source:,
          api_key_id: CurrentContext.api_key_id,
          user_id: user_id,
          activity_type:,
          activity_id:,
          logged_at: current_time,
          created_at: current_time,
          resource_id: resource.id,
          resource_type: resource.class.name,
          organization_id: organization_id,
          activity_object: object_serialized,
          activity_object_changes: object_changes(changes),
          external_customer_id: external_customer_id,
          external_subscription_id: external_subscription_id
        }.to_json
      )
    end

    def activity_source
      return "front" if CurrentContext.source == "graphql"

      CurrentContext.source || "system"
    end

    def user_id
      return nil if CurrentContext.api_key_id.present?
      return nil if CurrentContext.membership.blank?

      Membership.find_by(organization_id:, id: CurrentContext.membership.split("/").last)&.user_id
    end

    def object_serialized
      serializer = "V1::#{object.class.name}Serializer".constantize
      root_name = object.class.name.underscore.to_sym

      serializer.new(object, root_name:, includes: serializer_includes(root_name)).serialize
    end

    def serializer_includes(root_name)
      case root_name
      when :invoice
        if object.fees.count > MAX_SERIALIZED_FEES
          SERIALIZED_INCLUDED_OBJECTS[:invoice] - [:fees]
        else
          SERIALIZED_INCLUDED_OBJECTS[:invoice]
        end
      when :plan
        if has_many_charges_or_filters?(object)
          SERIALIZED_INCLUDED_OBJECTS[:plan] - [:charges]
        else
          SERIALIZED_INCLUDED_OBJECTS[:plan]
        end
      when :subscription
        if has_many_charges_or_filters?(object.plan)
          [{plan: SERIALIZED_INCLUDED_OBJECTS[:plan] - [:charges]}]
        else
          SERIALIZED_INCLUDED_OBJECTS[:subscription]
        end
      else
        SERIALIZED_INCLUDED_OBJECTS[root_name] || []
      end
    end

    def object_changes(changes)
      return {} unless activity_type.include?("updated")

      changes.except(*IGNORED_FIELDS)
    end

    def organization_id
      case object.class.name
      when "AppliedCoupon"
        object.coupon.organization_id
      else
        object.organization_id
      end
    end

    def resource
      case object.class.name
      when "Payment"
        object.payable
      when "AppliedCoupon"
        object.coupon
      when "WalletTransaction"
        object.wallet
      else
        object
      end
    end

    def external_customer_id
      return nil if IGNORED_EXTERNAL_CUSTOMER_ID_CLASSES.include?(object.class.name)
      return object.external_id if object.is_a?(Customer)

      object.customer&.external_id
    end

    def external_subscription_id
      return nil unless object.is_a?(Subscription)

      object.external_id
    end

    def has_many_charges_or_filters?(plan)
      plan.charges.count > MAX_SERIALIZED_CHARGES || plan.charge_filters.count > MAX_SERIALIZED_CHARGE_FILTERS
    end
  end
end
