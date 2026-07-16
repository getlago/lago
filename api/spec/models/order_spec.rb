# frozen_string_literal: true

require "rails_helper"

RSpec.describe Order do
  subject(:order) { build(:order, order_form: nil) }

  describe "enums" do
    it do
      expect(order).to define_enum_for(:status)
        .backed_by_column_of_type(:enum)
        .validating
        .with_values(created: "created", executed: "executed")
        .with_default(:created)

      expect(order).to define_enum_for(:execution_mode)
        .backed_by_column_of_type(:enum)
        .validating(allowing_nil: true)
        .with_values(execute_in_lago: "execute_in_lago", order_only: "order_only")
        .without_instance_methods
    end
  end

  describe "associations" do
    it do
      expect(order).to belong_to(:organization)
      expect(order).to belong_to(:customer)
      expect(order).to belong_to(:order_form)
      expect(order).to have_one(:quote_version).through(:order_form)
      expect(order).to have_one(:quote).through(:quote_version)
    end
  end

  describe "validations" do
    describe "execution_mode validation" do
      it "requires execution_mode when execute_at is set" do
        order = build(:order, execute_at: 1.day.from_now, execution_mode: nil)
        order.valid?
        expect(order.errors.added?(:execution_mode, :blank)).to be(true)
      end

      it "requires execution_mode when executed" do
        order = build(:order, status: :executed, execution_mode: nil)
        order.valid?
        expect(order.errors.added?(:execution_mode, :blank)).to be(true)
      end

      it "allows a blank execution_mode when created without execute_at" do
        order = build(:order, execute_at: nil, execution_mode: nil)
        order.valid?
        expect(order.errors.added?(:execution_mode, :blank)).to be(false)
      end

      it "accepts an executed order with each execution mode" do
        expect(build(:order, :executed_in_lago)).to be_valid
        expect(build(:order, :executed_order_only)).to be_valid
      end

      it "allows execution_mode without execute_at" do
        order = build(:order, execute_at: nil, execution_mode: :order_only)
        order.valid?
        expect(order.errors.added?(:execution_mode, :blank)).to be(false)
      end
    end
  end

  describe "sequencing" do
    it "assigns sequential ids per organization" do
      organization = create(:organization)
      customer = create(:customer, organization:)
      first = create(:order, organization:, customer:)
      second = create(:order, organization:, customer:)
      expect([first.sequential_id, second.sequential_id]).to eq([1, 2])
    end

    it "scopes the sequence per organization" do
      org_a = create(:organization)
      org_b = create(:organization)
      a1 = create(:order, organization: org_a, customer: create(:customer, organization: org_a))
      b1 = create(:order, organization: org_b, customer: create(:customer, organization: org_b))
      expect([a1.sequential_id, b1.sequential_id]).to eq([1, 1])
    end
  end

  describe "ensure_number callback" do
    it "assigns a formatted number when sequential_id and created_at are present" do
      order = create(:order, created_at: Time.zone.local(2020, 1, 2))
      expect(order.number).to eq("OR-2020-#{format("%04d", order.sequential_id)}")
    end

    it "uses the current year when created_at is blank on save" do
      travel_to(Time.zone.local(2026, 6, 1)) do
        order = create(:order, created_at: nil)
        expect(order.number).to eq("OR-2026-#{format("%04d", order.sequential_id)}")
      end
    end

    it "preserves an explicitly assigned number" do
      order = create(:order, number: "OR-CUSTOM-0001")
      expect(order.number).to eq("OR-CUSTOM-0001")
    end
  end
end
