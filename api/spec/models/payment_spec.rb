# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payment do
  subject(:payment) { build(:payment, payable:, payment_type:, provider_payment_id:, reference:, amount_cents:) }

  let(:payable) { create(:invoice, invoice_type:, total_amount_cents: 10000) }
  let(:invoice_type) { :subscription }
  let(:payment_type) { "provider" }
  let(:provider_payment_id) { SecureRandom.uuid }
  let(:reference) { nil }
  let(:amount_cents) { 200 }

  it_behaves_like "paper_trail traceable"

  it { is_expected.to have_many(:integration_resources) }
  it { is_expected.to have_one(:payment_receipt) }
  it { is_expected.to have_one(:invoice_settlement).with_foreign_key(:source_payment_id) }
  it { is_expected.to belong_to(:payable) }
  it { is_expected.to belong_to(:organization) }
  it { is_expected.to belong_to(:customer).optional }
  it { is_expected.to belong_to(:payment_method).optional }
  it { is_expected.to validate_presence_of(:payment_type) }

  it do
    expect(subject)
      .to define_enum_for(:payment_type)
      .with_values(Payment::PAYMENT_TYPES)
      .with_prefix(:payment_type)
      .backed_by_column_of_type(:enum)
  end

  describe "attributes" do
    describe "amount_currency" do
      before { payment.update(amount_currency: "BRL") }

      it "aliases to currency" do
        expect(payment.currency).to eq("BRL")
      end
    end
  end

  describe "delegations" do
    describe "billing_entity" do
      it "delegates to customer" do
        expect(payment.billing_entity).to be(payment.customer.billing_entity)
      end
    end
  end

  describe "validations" do
    let(:errors) { payment.errors }

    before { payment.valid? }

    describe "of amount cents" do
      before { payment.save }

      context "when payable is an invoice" do
        context "when invoice is not of a credit type" do
          context "when payment type is manual" do
            let(:payment_type) { "manual" }

            context "when amount cents does not equal invoice total amount cents" do
              it "does not add an error" do
                expect(errors.where(:amount_cents, :invalid_amount)).not_to be_present
              end
            end

            context "when amount cents equals invoice total amount cents" do
              let(:amount_cents) { payable.total_amount_cents }

              it "does not add an error" do
                expect(errors.where(:amount_cents, :invalid_amount)).not_to be_present
              end
            end
          end

          context "when payment type is provider" do
            let(:payment_type) { "provider" }

            context "when amount cents does not equal invoice total amount cents" do
              it "does not add an error" do
                expect(errors.where(:amount_cents, :invalid_amount)).not_to be_present
              end
            end

            context "when amount cents equals invoice total amount cents" do
              let(:amount_cents) { payable.total_amount_cents }

              it "does not add an error" do
                expect(errors.where(:amount_cents, :invalid_amount)).not_to be_present
              end
            end
          end
        end

        context "when invoice is of a credit type" do
          let(:invoice_type) { :credit }

          context "when payment type is manual" do
            let(:payment_type) { "manual" }

            context "when amount cents does not equal invoice total amount cents" do
              it "adds an error" do
                expect(errors.where(:amount_cents, :invalid_amount)).to be_present
              end
            end

            context "when amount cents equals invoice total amount cents" do
              let(:amount_cents) { payable.total_amount_cents }

              it "does not add an error" do
                expect(errors.where(:amount_cents, :invalid_amount)).not_to be_present
              end
            end
          end

          context "when payment type is provider" do
            let(:payment_type) { "provider" }

            context "when amount cents does not equal invoice total amount cents" do
              it "does not add an error" do
                expect(errors.where(:amount_cents, :invalid_amount)).not_to be_present
              end
            end

            context "when amount cents equals invoice total amount cents" do
              let(:amount_cents) { payable.total_amount_cents }

              it "does not add an error" do
                expect(errors.where(:amount_cents, :invalid_amount)).not_to be_present
              end
            end
          end
        end
      end

      context "when payable is a payment request" do
        let(:payable) { create(:payment_request) }

        context "when payment type is manual" do
          let(:payment_type) { "manual" }

          it "does not add an error" do
            expect(errors.where(:amount_cents, :invalid_amount)).not_to be_present
          end
        end

        context "when payment type is provider" do
          let(:payment_type) { "provider" }

          it "does not add an error" do
            expect(errors.where(:amount_cents, :invalid_amount)).not_to be_present
          end
        end
      end
    end

    describe "of max invoice paid amount cents" do
      before { payment.save }

      context "when payable is an invoice" do
        context "when payment type is provider" do
          let(:payment_type) { "provider" }

          context "when amount cents + total paid amount cents is smaller or equal than invoice total amount cents" do
            let(:payment_request) { create(:payment_request, payment_status: :succeeded) }

            it "does not add an error" do
              expect(errors.where(:amount_cents, :greater_than)).not_to be_present
            end
          end

          context "when amount cents + total paid amount cents is greater than invoice total amount cents" do
            let(:amount_cents) { 10001 }

            it "does not add an error" do
              expect(errors.where(:amount_cents, :greater_than)).not_to be_present
            end
          end
        end

        context "when payment type is manual" do
          let(:payment_type) { "manual" }

          context "when amount cents + total paid amount cents is smaller or equal than invoice total amount cents" do
            let(:payment_request) { create(:payment_request, payment_status: :succeeded) }

            it "does not add an error" do
              expect(errors.where(:amount_cents, :greater_than)).not_to be_present
            end
          end

          context "when amount cents + total paid amount cents is greater than invoice total amount cents" do
            let(:amount_cents) { 10001 }

            it "adds an error" do
              expect(errors.where(:amount_cents, :greater_than)).to be_present
            end
          end

          context "with offset amounts from credit notes" do
            let(:payable) { create(:invoice, total_amount_cents: 10000, total_paid_amount_cents: 3000) }

            it "allows payment within remaining due amount after offset" do
              create(:credit_note, invoice: payable, status: :finalized, offset_amount_cents: 2000)
              payment.amount_cents = 5000 # total_due = 10000 - 3000 - 2000 = 5000
              payment.save
              expect(errors.where(:amount_cents, :greater_than)).not_to be_present
            end

            it "rejects payment exceeding remaining due amount after offset" do
              create(:credit_note, invoice: payable, status: :finalized, offset_amount_cents: 2000)
              payment.amount_cents = 6000 # total_due = 10000 - 3000 - 2000 = 5000
              payment.save
              expect(errors.where(:amount_cents, :greater_than)).to be_present
            end

            it "sums multiple offset amounts correctly" do
              create(:credit_note, invoice: payable, status: :finalized, offset_amount_cents: 1500)
              create(:credit_note, invoice: payable, status: :finalized, offset_amount_cents: 1000)
              payment.amount_cents = 4500 # total_due = 10000 - 3000 - 2500 = 4500
              payment.save
              expect(errors.where(:amount_cents, :greater_than)).not_to be_present
            end

            it "rejects payment when invoice is fully settled by offsets" do
              payable.update!(total_paid_amount_cents: 6000)
              create(:credit_note, invoice: payable, status: :finalized, offset_amount_cents: 4000)
              payment.amount_cents = 1 # total_due = 10000 - 6000 - 4000 = 0
              payment.save
              expect(errors.where(:amount_cents, :greater_than)).to be_present
            end

            it "ignores draft credit notes when calculating due amount" do
              payable.update!(total_paid_amount_cents: 2000)
              create(:credit_note, invoice: payable, status: :draft, offset_amount_cents: 1000)
              payment.amount_cents = 8000 # total_due = 10000 - 2000 = 8000 (draft ignored)
              payment.save
              expect(errors.where(:amount_cents, :greater_than)).not_to be_present
            end
          end
        end
      end
    end

    describe "of payment request succeeded" do
      context "when payable is an invoice" do
        context "when payment type is provider" do
          let(:payment_type) { "provider" }

          context "when succeeded payment requests exist" do
            let(:payment_request) { create(:payment_request, payment_status: :succeeded) }

            before do
              create(:payment_request_applied_invoice, payment_request:, invoice: payable)
              payment.save
            end

            it "does not add an error" do
              expect(errors.where(:base, :payment_request_is_already_succeeded)).not_to be_present
            end
          end

          context "when no succeeded payment requests exist" do
            before { payment.save }

            it "does not add an error" do
              expect(errors.where(:base, :payment_request_is_already_succeeded)).not_to be_present
            end
          end
        end

        context "when payment type is manual" do
          let(:payment_type) { "manual" }

          context "when succeeded payment request exist" do
            let(:payment_request) { create(:payment_request, payment_status: "succeeded") }

            before do
              create(:payment_request_applied_invoice, payment_request:, invoice: payable)
              payment.save
            end

            it "adds an error" do
              expect(payment.errors.where(:base, :payment_request_is_already_succeeded)).to be_present
            end
          end

          context "when no succeeded payment requests exist" do
            before { payment.save }

            it "does not add an error" do
              expect(errors.where(:base, :payment_request_is_already_succeeded)).not_to be_present
            end
          end
        end
      end

      context "when payable is not an invoice" do
        let(:payable) { create(:payment_request) }

        context "when payment type is provider" do
          let(:payment_type) { "provider" }

          before { payment.save }

          it "does not add an error" do
            expect(errors.where(:base, :payment_request_is_already_succeeded)).not_to be_present
          end
        end

        context "when payment type is manual" do
          let(:payment_type) { "manual" }

          before { payment.save }

          it "does not add an error" do
            expect(errors.where(:base, :payment_request_is_already_succeeded)).not_to be_present
          end
        end
      end
    end

    describe "of reference" do
      context "when payment type is provider" do
        context "when reference is present" do
          let(:reference) { "123" }

          it "adds an error" do
            expect(errors.where(:reference, :present)).to be_present
          end
        end

        context "when reference is not present" do
          it "does not add an error" do
            expect(errors.where(:reference, :present)).not_to be_present
          end
        end
      end

      context "when payment type is manual" do
        let(:payment_type) { "manual" }

        context "when reference is not present" do
          it "adds an error" do
            expect(errors[:reference]).to include("value_is_mandatory")
          end
        end

        context "when reference is present" do
          context "when reference is less than 40 characters" do
            let(:reference) { "123" }

            it "does not add an error" do
              expect(errors.where(:reference, :blank)).not_to be_present
            end
          end

          context "when reference is more than 40 characters" do
            let(:reference) { "a" * 41 }

            it "adds an error" do
              expect(errors.where(:reference, :too_long)).to be_present
            end
          end
        end
      end
    end
  end

  describe "#invoices" do
    context "when payable is an invoice" do
      let(:payable) { create(:invoice) }

      it "returns the invoice as a ActiveRecord::Relation" do
        expect(subject.invoices).to be_a(ActiveRecord::Relation)
        expect(subject.invoices.sole).to eq payable
      end
    end

    context "when payable is a payment request" do
      let(:invoices) { create_list(:invoice, 2) }
      let(:payable) { create(:payment_request, invoices:) }

      it "returns the payment request invoices as a ActiveRecord::Relation" do
        expect(subject.invoices).to be_a ActiveRecord::Relation
        expect(subject.invoices).to match_array(invoices)
      end
    end
  end

  describe "#invoice_numbers" do
    context "when payable is an invoice" do
      let(:payable) { create(:invoice) }

      it "returns the invoice number" do
        expect(subject.invoice_numbers).to eq([payable.number])
      end
    end

    context "when payable is a payment request" do
      let(:invoices) { create_list(:invoice, 2) }
      let(:payable) { create(:payment_request, invoices:) }

      it "returns the payment request invoice numbers" do
        expect(subject.invoice_numbers).to match_array(invoices.map(&:number))
      end
    end
  end

  describe "#payment_provider_type" do
    subject(:payment_provider_type) { payment.payment_provider_type }

    let(:payment) { create(:payment, payment_provider:) }

    context "when payment provider is AdyenProvider" do
      let(:payment_provider) { create(:adyen_provider) }

      it "returns adyen" do
        expect(payment_provider_type).to eq("adyen")
      end
    end

    context "when payment provider is CashfreeProvider" do
      let(:payment_provider) { create(:cashfree_provider) }

      it "returns cashfree" do
        expect(payment_provider_type).to eq("cashfree")
      end
    end

    context "when payment provider is GocardlessProvider" do
      let(:payment_provider) { create(:gocardless_provider) }

      it "returns gocardless" do
        expect(payment_provider_type).to eq("gocardless")
      end
    end

    context "when payment provider is StripeProvider" do
      let(:payment_provider) { create(:stripe_provider) }

      it "returns stripe" do
        expect(payment_provider_type).to eq("stripe")
      end
    end

    context "when payment provider is nil" do
      let(:payment_provider) { nil }

      it "returns an empty string" do
        expect(payment_provider_type).to be_nil
      end
    end
  end

  describe "#method_display_name" do
    subject(:method_display_name) { payment.method_display_name }

    context "when provider_payment_method_data is empty" do
      let(:payment) { build(:payment, provider_payment_method_data: {}) }

      it "returns nil" do
        expect(method_display_name).to be_nil
      end
    end

    context "when provider_payment_method_data contains card details" do
      let(:payment) do
        build(:payment, provider_payment_method_data: {
          "type" => "card",
          "brand" => "visa",
          "last4" => "1234"
        })
      end

      it "returns formatted card details" do
        expect(method_display_name).to eq("Visa **** 1234")
      end
    end

    context "when provider_payment_method_data contains non-card details" do
      let(:payment) do
        build(:payment, provider_payment_method_data: {
          "type" => "bank_transfer"
        })
      end

      it "returns the payment method type" do
        expect(method_display_name).to eq("Bank Transfer")
      end
    end
  end

  describe "#card_last_digits" do
    subject { payment.card_last_digits }

    context "when provider_payment_method_data is empty" do
      let(:payment) { build(:payment, provider_payment_method_data: {}) }

      it { is_expected.to be_nil }
    end

    context "when provider_payment_method_data type is not card" do
      let(:payment) do
        build(:payment, provider_payment_method_data: {"type" => "link"})
      end

      it { is_expected.to be_nil }
    end

    context "when provider_payment_method_data type is card" do
      let(:payment) do
        build(:payment, provider_payment_method_data: {
          "type" => "card",
          "brand" => "visa",
          "last4" => "1234"
        })
      end

      it { is_expected.to eq("**** 1234") }
    end
  end

  describe "#should_sync_payment?" do
    subject(:method_call) { payment.should_sync_payment? }

    let(:payment) { create(:payment, payable: invoice) }
    let(:invoice) { create(:invoice, customer:, organization:, status:) }
    let(:organization) { create(:organization) }

    context "when invoice is not finalized" do
      let(:status) { %i[draft voided generating].sample }

      context "without integration customer" do
        let(:customer) { create(:customer, organization:) }

        it "returns false" do
          expect(method_call).to eq(false)
        end
      end

      context "with integration customer" do
        let(:integration_customer) { create(:netsuite_customer, integration:, customer:) }
        let(:integration) { create(:netsuite_integration, organization:, sync_payments:) }
        let(:customer) { create(:customer, organization:) }

        before { integration_customer }

        context "when sync payments is true" do
          let(:sync_payments) { true }

          it "returns false" do
            expect(method_call).to eq(false)
          end
        end

        context "when sync payments is false" do
          let(:sync_payments) { false }

          it "returns false" do
            expect(method_call).to eq(false)
          end
        end
      end
    end

    context "when invoice is finalized" do
      let(:status) { :finalized }

      context "without integration customer" do
        let(:customer) { create(:customer, organization:) }

        it "returns false" do
          expect(method_call).to eq(false)
        end
      end

      context "with integration customer" do
        let(:integration_customer) { create(:netsuite_customer, integration:, customer:) }
        let(:integration) { create(:netsuite_integration, organization:, sync_payments:) }
        let(:customer) { create(:customer, organization:) }

        before { integration_customer }

        context "when sync payments is true" do
          let(:sync_payments) { true }

          it "returns true" do
            expect(method_call).to eq(true)
          end
        end

        context "when sync payments is false" do
          let(:sync_payments) { false }

          it "returns false" do
            expect(method_call).to eq(false)
          end
        end
      end
    end
  end

  describe ".for_organization" do
    subject(:result) { described_class.for_organization(organization) }

    let(:organization) { create(:organization) }
    let(:visible_invoice) { create(:invoice, organization:, status: Invoice::VISIBLE_STATUS[:finalized]) }
    let(:invisible_invoice) { create(:invoice, organization:, status: Invoice::INVISIBLE_STATUS[:generating]) }
    let(:payment_request) { create(:payment_request, organization:) }
    let(:other_org_payment_request) { create(:payment_request) }

    let(:visible_invoice_payment) { create(:payment, payable: visible_invoice) }
    let(:invisible_invoice_payment) { create(:payment, payable: invisible_invoice) }
    let(:payment_request_payment) { create(:payment, payable: payment_request) }
    let(:other_org_invoice_payment) { create(:payment) }
    let(:other_org_payment_request_payment) { create(:payment, payable: other_org_payment_request) }

    before do
      visible_invoice_payment
      invisible_invoice_payment
      payment_request_payment

      other_org_invoice_payment
      other_org_payment_request_payment
    end

    it "returns payments and payment requests for the organization's visible invoices" do
      payments = subject

      expect(payments).to include(visible_invoice_payment)
      expect(payments).to include(payment_request_payment)
      expect(payments).not_to include(invisible_invoice_payment)
      expect(payments).not_to include(other_org_invoice_payment)
      expect(payments).not_to include(other_org_payment_request_payment)
    end
  end

  describe ".customer" do
    context "with discarded customer" do
      before do
        payment.customer.discard
        payment.save!
      end

      it "loads the discarded customer" do
        payment.reload
        expect(payment.customer).not_to be_nil
      end
    end
  end
end
