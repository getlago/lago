# frozen_string_literal: true

# Shared contract for any model that `include HasPurchaseOrderNumber`.
# The host group must define `subject` as a buildable instance of the model.
RSpec.shared_examples "a model with a purchase order number" do
  describe "purchase_order_number" do
    it { is_expected.to validate_length_of(:purchase_order_number).is_at_most(255) }

    describe "normalization" do
      it "trims surrounding whitespace" do
        subject.purchase_order_number = "  PO-123  "
        subject.valid?
        expect(subject.purchase_order_number).to eq("PO-123")
      end

      it "converts blank to nil" do
        subject.purchase_order_number = "   "
        subject.valid?
        expect(subject.purchase_order_number).to be_nil
      end

      it "preserves the original case" do
        subject.purchase_order_number = "  Po-AbC-123 "
        subject.valid?
        expect(subject.purchase_order_number).to eq("Po-AbC-123")
      end
    end
  end
end
