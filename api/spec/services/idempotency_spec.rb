# frozen_string_literal: true

require "rails_helper"

RSpec.describe Idempotency, transaction: false do
  describe ".transaction" do
    let(:customer) { create(:customer) }
    let(:invoice) { create(:invoice) }

    context "when no components are added" do
      it "raises an ArgumentError" do
        expect do
          described_class.transaction {}
        end.to raise_error(ArgumentError, "At least one resource must be added")
      end
    end

    context "when already in a transaction" do
      it "raises an ArgumentError" do
        allow(ApplicationRecord.connection).to receive(:open_transactions).and_return(1)

        expect do
          described_class.transaction do
            # No operations
          end
        end.to raise_error(ArgumentError, "An idempotent_transaction cannot be created in a transaction. (1 open transactions)")
      end
    end

    context "when operation succeeds" do
      it "executes the block" do
        block_executed = false

        described_class.transaction do
          block_executed = true
          described_class.unique!(invoice, id: invoice.id, issuing_date: invoice.issuing_date)
        end

        expect(block_executed).to be true
      end

      it "creates an idempotency record with the correct key and resource" do
        described_class.transaction do
          described_class.unique!(invoice, id: invoice.id, issuing_date: invoice.issuing_date)
        end
      end

      it "supports multiple resources in the same transaction" do
        described_class.transaction do
          described_class.unique!(invoice, id: invoice.id, issuing_date: invoice.issuing_date)
          described_class.unique!(customer, id: customer.id)
        end
      end

      it "supports multiple value arrays for the same resource" do
        described_class.transaction do
          described_class.unique!(invoice, id: invoice.id, issuing_date: invoice.issuing_date)
          described_class.unique!(invoice, id: invoice.customer_id)
        end
      end

      it "returns the original result of the block" do
        block_return_value = "expected return value"

        result = described_class.transaction do
          described_class.unique!(invoice, id: invoice.id)
          block_return_value
        end

        expect(result).to eq(block_return_value)
      end
    end

    context "when returning early from the transaction" do
      it "raises an error" do
        # define method so we don't have a local jump error
        def test_func
          described_class.transaction do
            return 1 # rubocop:disable Rails/TransactionExitStatement
          end
        end

        expect do
          test_func
        end.to raise_error(Idempotency::IdempotencyError, "You've returned early from an Idempotency transaction, please use `next` instead")
      end

      it "does not create an idempotency_record" do
        def test_func
          described_class.transaction do
            described_class.unique!(invoice, id: invoice.id)
            return 1 # rubocop:disable Rails/TransactionExitStatement
          end
        end

        expect do
          test_func
        rescue # test_func raises so we rescue
          nil
        end.not_to change(IdempotencyRecord, :count)
      end

      it "does not create a customer" do
        def test_func
          described_class.transaction do
            create(:customer)
            return 1 # rubocop:disable Rails/TransactionExitStatement
          end
        end

        expect do
          test_func
        rescue => e
          expect(e).to be_instance_of(Idempotency::IdempotencyError)
        end.not_to change(Customer, :count)
      end

      it "does not create a customer when raising a rollback" do
        def test_func
          described_class.transaction do
            create(:customer)
            raise ActiveRecord::Rollback
          end
        end

        expect do
          test_func
        end.not_to change(Customer, :count)

        expect do
          test_func
        end.not_to raise_error
      end
    end

    context "when an idempotency error occurs" do
      it "raises an IdempotencyError" do
        # Execute the transaction once
        described_class.transaction do
          described_class.unique!(invoice, id: invoice.id)
        end

        # This one should now fail!
        expect do
          described_class.transaction do
            described_class.unique!(invoice, id: invoice.id)
          end
        end.to raise_error(Idempotency::IdempotencyError, "Idempotency key already exists for resource [#{invoice.to_gid}] based on {id: \"#{invoice.id}\"}.")
      end
    end

    context "when an exception occurs in the block" do
      it "cleans up the transaction context" do
        begin
          described_class.transaction do
            described_class.unique!(invoice, id: invoice.id)
            raise "Test error"
          end
        rescue => e
          expect(e).to be_instance_of(RuntimeError)
        end

        expect(described_class.current_transaction).to be_nil
      end

      it "propagates the exception" do
        expect do
          described_class.transaction do
            described_class.unique!(invoice, id: invoice.id)
            raise "Test error"
          end
        end.to raise_error("Test error")
      end
    end
  end

  describe ".unique!" do
    context "when called outside of a transaction" do
      it "raises an ArgumentError" do
        expect do
          described_class.unique!("resource", key: "value")
        end.to raise_error(ArgumentError, "Idempotency.unique! can only be called within an idempotent_transaction block")
      end
    end

    context "when called inside a transaction" do
      it "adds the values to the resource in the current transaction" do
        values_added = nil
        resource = create(:event)

        described_class.transaction do
          described_class.unique!(resource, v1: "value1", v2: "value2")
          values_added = described_class.current_transaction.idempotent_resources[resource]
        end

        expect(values_added).to eq({v1: "value1", v2: "value2"})
      end

      it "merges multiple calls to unique for the same resource" do
        resource = create(:event)
        values_list = nil

        described_class.transaction do
          described_class.unique!(resource, v1: "value1")
          described_class.unique!(resource, v2: "value2", v3: "value3")
          values_list = described_class.current_transaction.idempotent_resources[resource]
        end

        expect(values_list).to eq({v1: "value1", v2: "value2", v3: "value3"})
      end

      it "merges multiple calls to unique for the same resource and uses the last key-value pair" do
        resource = create(:event)
        values_list = nil

        described_class.transaction do
          described_class.unique!(resource, v1: "value1")
          described_class.unique!(resource, v1: "value2", v3: "value3")
          values_list = described_class.current_transaction.idempotent_resources[resource]
        end

        expect(values_list).to eq({v1: "value2", v3: "value3"})
      end

      it "returns an error if no key-value pairs are provided" do
        resource = create(:event)
        expect do
          described_class.transaction do
            expect { described_class.unique!(resource) }.to raise_error(ArgumentError)
          end
        end.to raise_error(ArgumentError, "At least one resource must be added")
      end
    end
  end

  describe "Transaction" do
    let(:transaction) { described_class::Transaction.new }
    let(:invoice) { create(:invoice) }

    describe "#ensure_idempotent!" do
      it "creates idempotency records for each resource" do
        resource1 = create(:event)
        resource2 = create(:event)
        values1 = {c1: "a", c2: "D"}
        values2 = {c2: "d"}

        transaction.idempotent_resources[resource1] = values1
        transaction.idempotent_resources[resource2] = values2

        expect { transaction.ensure_idempotent! }.to change(IdempotencyRecord, :count).by(2)
      end
    end

    describe "#valid?" do
      it "returns true when resources are present" do
        resource = create(:event)
        transaction.idempotent_resources[resource] = [["value"]]
        expect(transaction.valid?).to be true
      end

      it "returns false when resources are empty" do
        expect(transaction.valid?).to be false
      end
    end
  end
end
