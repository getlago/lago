# frozen_string_literal: true

class GraphqlChannel < ApplicationCable::Channel
  def subscribed
  end

  def execute(data)
    query = data["query"]
    variables = ensure_hash(data["variables"])
    operation_name = data["operationName"]
    context = {channel: self}

    result = LagoApiSchema.execute(query, context:, variables:, operation_name:)
    payload = {result: result.to_h}

    # Track the subscription here so we can remove it on unsubscribe.
    if result.context[:subscription_id]
      @subscription_ids ||= []
      @subscription_ids << result.context[:subscription_id]
    end

    if result.context[:subscription_id]
      transmit(payload.merge(more: true))
    else
      transmit(payload.merge(more: false))
    end
  end

  def unsubscribed
    @subscription_ids.each { |id| LagoApiSchema.subscriptions.delete_subscription(id) }
  end

  private

  def ensure_hash(ambiguous_param)
    case ambiguous_param
    when String
      if ambiguous_param.present?
        ensure_hash(JSON.parse(ambiguous_param))
      else
        {}
      end
    when Hash, ActionController::Parameters
      ambiguous_param
    when nil
      {}
    else
      raise ArgumentError, "Unexpected parameter: #{ambiguous_param}"
    end
  end
end
