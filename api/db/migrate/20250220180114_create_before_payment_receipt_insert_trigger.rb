# frozen_string_literal: true

class CreateBeforePaymentReceiptInsertTrigger < ActiveRecord::Migration[7.1]
  def up
    safety_assured do
      execute <<-SQL
        CREATE OR REPLACE FUNCTION set_payment_receipt_number()
        RETURNS trigger AS $$
        DECLARE
            cust_id uuid;
            next_payment_receipt integer;
            document_number_prefix character varying;
        BEGIN
          IF NEW.number IS NULL THEN
            SELECT i.customer_id INTO cust_id
            FROM invoices i
            INNER JOIN payments p ON (p.payable_id = i.id AND p.payable_type = 'Invoice')
            WHERE p.id = NEW.payment_id;

            IF cust_id IS NULL THEN
              SELECT pr.customer_id INTO cust_id
              FROM payment_requests pr
              LEFT JOIN payments p ON (p.payable_id = pr.id AND p.payable_type = 'PaymentRequest')
              WHERE p.id = NEW.payment_id;
            END IF;

            SELECT c.slug INTO document_number_prefix
            FROM customers c
            WHERE c.id = cust_id;

            -- Atomically increment the customer's payment receipt counter and get the new value
            UPDATE customers
            SET payment_receipt_counter = payment_receipt_counter + 1
            WHERE id = cust_id
            RETURNING payment_receipt_counter INTO next_payment_receipt;

            -- Construct the payment receipt number using the customer id and the new counter value
            NEW.number := document_number_prefix || '-RCPT-' || LPAD(next_payment_receipt::text, GREATEST(6, LENGTH(next_payment_receipt::text)), '0');
          END IF;
          RETURN NEW;
        END;
        $$ LANGUAGE plpgsql;
      SQL

      execute <<-SQL
        CREATE TRIGGER before_payment_receipt_insert
        BEFORE INSERT ON payment_receipts
        FOR EACH ROW
        EXECUTE FUNCTION set_payment_receipt_number();
      SQL
    end
  end

  def down
    execute <<-SQL
      DROP TRIGGER IF EXISTS before_payment_receipt_insert ON payment_receipts;
    SQL

    execute <<-SQL
      DROP FUNCTION IF EXISTS set_payment_receipt_number;
    SQL
  end
end
