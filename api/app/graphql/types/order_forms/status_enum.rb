# frozen_string_literal: true

module Types
  module OrderForms
    class StatusEnum < Types::BaseEnum
      graphql_name "OrderFormStatusEnum"

      OrderForm::STATUSES.each_key do |type|
        value type
      end
    end
  end
end
