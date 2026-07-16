# frozen_string_literal: true

module Invoices
  module Payments
    # Raised right before an off-session charge when the payable has already been settled
    # by another payment path (e.g. a hosted checkout session). Signals the caller to abort
    # the charge without delivering an error webhook or scheduling a retry.
    class AlreadyPaidError < StandardError; end
  end
end
