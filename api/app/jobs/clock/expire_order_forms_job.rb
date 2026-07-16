# frozen_string_literal: true

module Clock
  class ExpireOrderFormsJob < ClockJob
    unique :until_executed, on_conflict: :log

    def perform
      OrderForm.expirable.find_each do |order_form|
        OrderForms::ExpireOrderFormJob.perform_later(order_form)
      end
    end
  end
end
