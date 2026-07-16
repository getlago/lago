# frozen_string_literal: true

module HasPurchaseOrderNumber
  extend ActiveSupport::Concern

  PURCHASE_ORDER_NUMBER_MAX_LENGTH = 255

  included do
    validates :purchase_order_number,
      length: {maximum: PURCHASE_ORDER_NUMBER_MAX_LENGTH}, allow_nil: true

    normalizes :purchase_order_number, with: ->(value) { value.strip.presence }
  end
end
