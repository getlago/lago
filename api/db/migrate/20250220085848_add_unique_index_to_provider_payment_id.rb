# frozen_string_literal: true

class AddUniqueIndexToProviderPaymentId < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    safety_assured do
      duplicates = Payment
        .select(:payment_provider_id, :provider_payment_id)
        .where.not(provider_payment_id: nil)
        .group(:payment_provider_id, :provider_payment_id)
        .having("COUNT(*) > 1")
        .pluck(:payment_provider_id, :provider_payment_id)

      duplicates.each do |duplicate|
        payments = Payment.where(
          payment_provider_id: duplicate.first,
          provider_payment_id: duplicate.last
        )
        payments_with_refund = payments.where.associated(:refunds).pluck(:id)

        if payments_with_refund.count > 0
          payments.where.not(id: payments_with_refund).delete_all
        else
          id = payments.order(created_at: :asc).first.id
          payments.where.not(id:).delete_all
        end
      end

      execute <<-SQL
        UPDATE invoices i
        SET total_paid_amount_cents = total_amount_cents
        WHERE total_paid_amount_cents > total_amount_cents;
      SQL

      add_index :payments,
        %i[provider_payment_id payment_provider_id],
        unique: true,
        where: "provider_payment_id IS NOT NULL",
        algorithm: :concurrently
    end
  end

  def down
    safety_assured do
      remove_index :payments, %i[provider_payment_id payment_provider_id]
    end
  end
end
