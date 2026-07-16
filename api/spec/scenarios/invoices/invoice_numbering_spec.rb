# frozen_string_literal: true

require "rails_helper"

describe "Invoice Numbering Scenario", transaction: false do
  let(:customer_first) { create(:customer, organization:, billing_entity: billing_entity_first) }
  let(:customer_second) { create(:customer, organization:, billing_entity: billing_entity_first) }
  let(:customer_third) { create(:customer, organization:, billing_entity: billing_entity_first) }
  let(:subscription_at) { DateTime.new(2023, 7, 19, 12, 12) }

  let(:organization) do
    create(:organization, document_number_prefix: "ORG-1", webhook_url: nil)
  end

  let(:billing_entity_first) do
    create(
      :billing_entity,
      organization:,
      document_numbering: "per_customer",
      timezone: "Europe/Paris",
      email_settings: [],
      document_number_prefix: "BENT-1"
    )
  end

  let(:monthly_plan) do
    create(
      :plan,
      organization:,
      interval: "monthly",
      amount_cents: 12_900,
      pay_in_advance: true
    )
  end
  let(:yearly_plan) do
    create(
      :plan,
      organization:,
      interval: "yearly",
      amount_cents: 100_000,
      pay_in_advance: true
    )
  end

  before do
    organization.webhook_endpoints.destroy_all
  end

  it "creates invoice numbers correctly" do
    # NOTE: Jul 19th: create the subscription
    travel_to(subscription_at) do
      create_subscription(
        {
          external_customer_id: customer_first.external_id,
          external_id: customer_first.external_id,
          plan_code: monthly_plan.code,
          billing_time: "anniversary",
          subscription_at: subscription_at.iso8601
        }
      )
      create_subscription(
        {
          external_customer_id: customer_second.external_id,
          external_id: customer_second.external_id,
          plan_code: monthly_plan.code,
          billing_time: "anniversary",
          subscription_at: subscription_at.iso8601
        }
      )
      create_subscription(
        {
          external_customer_id: customer_third.external_id,
          external_id: customer_third.external_id,
          plan_code: monthly_plan.code,
          billing_time: "anniversary",
          subscription_at: subscription_at.iso8601
        }
      )

      invoices = organization.invoices.order(created_at: :desc).limit(3)
      sequential_ids = invoices.pluck(:sequential_id)
      organization_sequential_ids = invoices.pluck(:organization_sequential_id)
      billing_entity_sequential_ids = invoices.pluck(:billing_entity_sequential_id)
      numbers = invoices.pluck(:number)

      expect(sequential_ids).to match_array([1, 1, 1])
      expect(organization_sequential_ids).to match_array([0, 0, 0])
      expect(billing_entity_sequential_ids).to match_array([nil, nil, nil])
      expect(numbers).to match_array(%w[BENT-1-001-001 BENT-1-002-001 BENT-1-003-001])
    end

    # NOTE: August 19th: Bill subscription
    travel_to(DateTime.new(2023, 8, 19, 12, 12)) do
      perform_billing

      invoices = organization.invoices.order(created_at: :desc).limit(3)
      sequential_ids = invoices.pluck(:sequential_id)
      organization_sequential_ids = invoices.pluck(:organization_sequential_id)
      billing_entity_sequential_ids = invoices.pluck(:billing_entity_sequential_id)
      numbers = invoices.pluck(:number)

      expect(sequential_ids).to match_array([2, 2, 2])
      expect(organization_sequential_ids).to match_array([0, 0, 0])
      expect(billing_entity_sequential_ids).to match_array([nil, nil, nil])
      expect(numbers).to match_array(%w[BENT-1-001-002 BENT-1-002-002 BENT-1-003-002])
    end

    # NOTE: September 19th: Bill subscription
    travel_to(DateTime.new(2023, 9, 19, 12, 12)) do
      perform_billing

      invoices = organization.invoices.order(created_at: :desc).limit(3)
      sequential_ids = invoices.pluck(:sequential_id)
      organization_sequential_ids = invoices.pluck(:organization_sequential_id)
      billing_entity_sequential_ids = invoices.pluck(:billing_entity_sequential_id)
      numbers = invoices.pluck(:number)

      expect(sequential_ids).to match_array([3, 3, 3])
      expect(organization_sequential_ids).to match_array([0, 0, 0])
      expect(billing_entity_sequential_ids).to match_array([nil, nil, nil])
      expect(numbers).to match_array(%w[BENT-1-001-003 BENT-1-002-003 BENT-1-003-003])
    end

    # NOTE: October 19th: Switching to per_organization numbering and Bill subscription
    travel_to(DateTime.new(2023, 10, 19, 12, 12)) do
      update_organization({document_numbering: "per_organization", document_number_prefix: "BENT-11"})

      perform_billing

      invoices = organization.invoices.order(created_at: :desc).limit(3)
      sequential_ids = invoices.pluck(:sequential_id)
      organization_sequential_ids = invoices.pluck(:organization_sequential_id)
      billing_entity_sequential_ids = invoices.pluck(:billing_entity_sequential_id)
      numbers = invoices.pluck(:number)

      expect(sequential_ids).to match_array([4, 4, 4])
      # we won't be filling organization_sequential_id as soon as we switch to per_billing_entity numbering
      expect(organization_sequential_ids).to match_array([0, 0, 0])
      expect(billing_entity_sequential_ids).to match_array([10, 11, 12])
      expect(numbers).to match_array(%w[BENT-11-202310-010 BENT-11-202310-011 BENT-11-202310-012])
    end

    # NOTE: November 19th: Switching to per_customer numbering and Bill subscription
    travel_to(DateTime.new(2023, 11, 19, 12, 12)) do
      update_organization({document_numbering: "per_customer"})

      perform_billing

      invoices = organization.invoices.order(created_at: :desc).limit(3)
      sequential_ids = invoices.pluck(:sequential_id)
      organization_sequential_ids = invoices.pluck(:organization_sequential_id)
      billing_entity_sequential_ids = invoices.pluck(:billing_entity_sequential_id)
      numbers = invoices.pluck(:number)

      expect(sequential_ids).to match_array([5, 5, 5])
      expect(organization_sequential_ids).to match_array([0, 0, 0])
      expect(billing_entity_sequential_ids).to match_array([nil, nil, nil])
      expect(numbers).to match_array(%w[BENT-11-001-005 BENT-11-002-005 BENT-11-003-005])
    end

    # NOTE: November 22: New subscription for second customer
    time = DateTime.new(2023, 11, 22, 12, 12)
    travel_to(time) do
      create_subscription(
        {
          external_customer_id: customer_second.external_id,
          external_id: "new_external_id",
          plan_code: yearly_plan.code,
          billing_time: "anniversary",
          subscription_at: time.iso8601
        }
      )

      invoices = organization.reload.invoices.order(created_at: :desc)

      expect(invoices.first.sequential_id).to eq(6)
      expect(invoices.first.organization_sequential_id).to be_zero
      expect(invoices.first.billing_entity_sequential_id).to be_nil
      expect(invoices.pluck(:number))
        .to match_array(
          %w[
            BENT-1-001-001
            BENT-1-002-001
            BENT-1-003-001
            BENT-1-001-002
            BENT-1-002-002
            BENT-1-003-002
            BENT-1-001-003
            BENT-1-002-003
            BENT-1-003-003
            BENT-11-202310-010
            BENT-11-202310-011
            BENT-11-202310-012
            BENT-11-001-005
            BENT-11-002-005
            BENT-11-003-005
            BENT-11-002-006
          ]
        )
    end

    # NOTE: December 19th: Switching to per_organization numbering and Bill subscription
    travel_to(DateTime.new(2023, 12, 19, 12, 12)) do
      update_organization({document_numbering: "per_organization"})

      perform_billing

      invoices = organization.invoices.order(created_at: :desc).limit(3)
      sequential_ids = invoices.pluck(:sequential_id)
      organization_sequential_ids = invoices.pluck(:organization_sequential_id)
      billing_entity_sequential_ids = invoices.pluck(:billing_entity_sequential_id)
      numbers = invoices.pluck(:number)

      expect(sequential_ids).to match_array([6, 6, 7])
      # we won't be filling organization_sequential_id as soon as we switch to per_billing_entity numbering
      expect(organization_sequential_ids).to match_array([0, 0, 0])
      expect(billing_entity_sequential_ids).to match_array([17, 18, 19])
      expect(numbers).to match_array(%w[BENT-11-202312-017 BENT-11-202312-018 BENT-11-202312-019])
    end

    # NOTE: January 19th 2024: Billing subscription
    travel_to(DateTime.new(2024, 1, 19, 12, 12)) do
      perform_billing

      invoices = organization.invoices.order(created_at: :desc).limit(3)
      sequential_ids = invoices.pluck(:sequential_id)
      organization_sequential_ids = invoices.pluck(:organization_sequential_id)
      billing_entity_sequential_ids = invoices.pluck(:billing_entity_sequential_id)
      numbers = invoices.pluck(:number)

      expect(sequential_ids).to match_array([7, 7, 8])
      # we won't be filling organization_sequential_id as soon as we switch to per_billing_entity numbering
      expect(organization_sequential_ids).to match_array([0, 0, 0])
      expect(billing_entity_sequential_ids).to match_array([20, 21, 22])
      expect(numbers).to match_array(%w[BENT-11-202401-020 BENT-11-202401-021 BENT-11-202401-022])
    end
  end

  context "with organization timezone" do
    it "creates invoice numbers correctly" do
      # NOTE: Jul 19th: create the subscription
      travel_to(subscription_at) do
        create_subscription(
          {
            external_customer_id: customer_first.external_id,
            external_id: customer_first.external_id,
            plan_code: monthly_plan.code,
            billing_time: "calendar",
            subscription_at: subscription_at.iso8601
          }
        )
        create_subscription(
          {
            external_customer_id: customer_second.external_id,
            external_id: customer_second.external_id,
            plan_code: monthly_plan.code,
            billing_time: "calendar",
            subscription_at: subscription_at.iso8601
          }
        )
        create_subscription(
          {
            external_customer_id: customer_third.external_id,
            external_id: customer_third.external_id,
            plan_code: monthly_plan.code,
            billing_time: "calendar",
            subscription_at: subscription_at.iso8601
          }
        )

        invoices = organization.invoices.order(created_at: :desc).limit(3)
        sequential_ids = invoices.pluck(:sequential_id)
        organization_sequential_ids = invoices.pluck(:organization_sequential_id)
        billing_entity_sequential_ids = invoices.pluck(:billing_entity_sequential_id)
        numbers = invoices.pluck(:number)

        expect(sequential_ids).to match_array([1, 1, 1])
        expect(organization_sequential_ids).to match_array([0, 0, 0])
        expect(billing_entity_sequential_ids).to match_array([nil, nil, nil])
        expect(numbers).to match_array(%w[BENT-1-001-001 BENT-1-002-001 BENT-1-003-001])
      end

      # NOTE: August 1st: Bill subscription
      travel_to(DateTime.new(2023, 8, 1, 0, 0)) do
        perform_billing

        invoices = organization.invoices.order(created_at: :desc).limit(3)
        sequential_ids = invoices.pluck(:sequential_id)
        organization_sequential_ids = invoices.pluck(:organization_sequential_id)
        billing_entity_sequential_ids = invoices.pluck(:billing_entity_sequential_id)
        numbers = invoices.pluck(:number)

        expect(sequential_ids).to match_array([2, 2, 2])
        expect(organization_sequential_ids).to match_array([0, 0, 0])
        expect(billing_entity_sequential_ids).to match_array([nil, nil, nil])
        expect(numbers).to match_array(%w[BENT-1-001-002 BENT-1-002-002 BENT-1-003-002])
      end

      # NOTE: September 1st: Bill subscription
      travel_to(DateTime.new(2023, 9, 1, 0, 0)) do
        perform_billing

        invoices = organization.invoices.order(created_at: :desc).limit(3)
        sequential_ids = invoices.pluck(:sequential_id)
        organization_sequential_ids = invoices.pluck(:organization_sequential_id)
        billing_entity_sequential_ids = invoices.pluck(:billing_entity_sequential_id)
        numbers = invoices.pluck(:number)

        expect(sequential_ids).to match_array([3, 3, 3])
        expect(organization_sequential_ids).to match_array([0, 0, 0])
        expect(billing_entity_sequential_ids).to match_array([nil, nil, nil])
        expect(numbers).to match_array(%w[BENT-1-001-003 BENT-1-002-003 BENT-1-003-003])
      end

      timezone = "Europe/Paris"
      customer_first.update(timezone:)
      customer_second.update(timezone:)
      customer_third.update(timezone:)

      # NOTE: October 1st: Switching to per_organization numbering and Bill subscription
      travel_to(DateTime.new(2023, 9, 30, 23, 10)) do
        update_organization({document_numbering: "per_organization", document_number_prefix: "BENT-11"})

        perform_billing

        invoices = organization.invoices.order(created_at: :desc).limit(3)
        sequential_ids = invoices.pluck(:sequential_id)
        organization_sequential_ids = invoices.pluck(:organization_sequential_id)
        billing_entity_sequential_ids = invoices.pluck(:billing_entity_sequential_id)
        numbers = invoices.pluck(:number)

        expect(sequential_ids).to match_array([4, 4, 4])
        # we won't be filling organization_sequential_id as soon as we switch to per_billing_entity numbering
        expect(organization_sequential_ids).to match_array([0, 0, 0])
        expect(billing_entity_sequential_ids).to match_array([10, 11, 12])
        expect(numbers).to match_array(%w[BENT-11-202310-010 BENT-11-202310-011 BENT-11-202310-012])
      end
    end
  end

  context "with grace period and per_customer numbering" do
    let(:customer_second) { create(:customer, organization:, invoice_grace_period: 2) }

    it "creates invoice numbers correctly" do
      # NOTE: Jul 19th: create the subscription
      travel_to(subscription_at) do
        create_subscription(
          {
            external_customer_id: customer_first.external_id,
            external_id: customer_first.external_id,
            plan_code: monthly_plan.code,
            billing_time: "anniversary",
            subscription_at: subscription_at.iso8601
          }
        )
        create_subscription(
          {
            external_customer_id: customer_second.external_id,
            external_id: customer_second.external_id,
            plan_code: monthly_plan.code,
            billing_time: "anniversary",
            subscription_at: subscription_at.iso8601
          }
        )
        create_subscription(
          {
            external_customer_id: customer_third.external_id,
            external_id: customer_third.external_id,
            plan_code: monthly_plan.code,
            billing_time: "anniversary",
            subscription_at: subscription_at.iso8601
          }
        )

        invoices = organization.invoices.order(created_at: :desc).limit(3)
        sequential_ids = invoices.pluck(:sequential_id)
        organization_sequential_ids = invoices.pluck(:organization_sequential_id)
        billing_entity_sequential_ids = invoices.pluck(:billing_entity_sequential_id)
        numbers = invoices.pluck(:number)

        expect(sequential_ids).to match_array([1, nil, 1])
        expect(organization_sequential_ids).to match_array([0, 0, 0])
        expect(billing_entity_sequential_ids).to match_array([nil, nil, nil])
        expect(numbers).to match_array(%w[BENT-1-001-001 BENT-1-DRAFT BENT-1-003-001])
      end

      # NOTE: Jul 20th: New subscription for the first customer
      time = subscription_at + 1.day
      travel_to(time) do
        create_subscription(
          {
            external_customer_id: customer_first.external_id,
            external_id: "new_external_id",
            plan_code: yearly_plan.code,
            billing_time: "anniversary",
            subscription_at: time.iso8601
          }
        )

        invoices = organization.reload.invoices.order(created_at: :desc)

        expect(invoices.first.sequential_id).to eq(2)
        expect(invoices.first.organization_sequential_id).to be_zero
        expect(invoices.first.billing_entity_sequential_id).to be_nil
        expect(invoices.pluck(:number))
          .to match_array(
            %w[
              BENT-1-001-001
              BENT-1-DRAFT
              BENT-1-003-001
              BENT-1-001-002
            ]
          )
      end

      # NOTE: Jul 21st: New subscription for the second customer
      time = subscription_at + 2.days
      travel_to(time) do
        create_subscription(
          {
            external_customer_id: customer_second.external_id,
            external_id: "new_external_id_2",
            plan_code: yearly_plan.code,
            billing_time: "anniversary",
            subscription_at: time.iso8601
          }
        )

        invoices = organization.reload.invoices.order(created_at: :desc)

        expect(invoices.first.sequential_id).to be_nil
        expect(invoices.first.organization_sequential_id).to be_zero
        expect(invoices.first.billing_entity_sequential_id).to be_nil
        expect(invoices.pluck(:number))
          .to match_array(
            %w[
              BENT-1-001-001
              BENT-1-DRAFT
              BENT-1-003-001
              BENT-1-001-002
              BENT-1-DRAFT
            ]
          )
      end

      travel_to(time + 1.hour) do
        draft_invoice1 = customer_second.reload.invoices.draft.order(created_at: :asc).first

        finalize_invoice(draft_invoice1)

        invoices = organization.reload.invoices.order(created_at: :desc)

        expect(invoices.pluck(:number))
          .to match_array(
            %w[
              BENT-1-001-001
              BENT-1-002-001
              BENT-1-003-001
              BENT-1-001-002
              BENT-1-DRAFT
            ]
          )
      end

      travel_to(time + 2.hours) do
        draft_invoice2 = customer_second.reload.invoices.draft.order(created_at: :asc).last

        finalize_invoice(draft_invoice2)

        invoices = organization.reload.invoices.order(created_at: :desc)

        expect(invoices.pluck(:number))
          .to match_array(
            %w[
              BENT-1-001-001
              BENT-1-002-001
              BENT-1-003-001
              BENT-1-001-002
              BENT-1-002-002
            ]
          )
      end

      # NOTE: August 19th: Bill subscription
      travel_to(DateTime.new(2023, 8, 19, 12, 12)) do
        perform_billing

        invoices = organization.invoices.order(created_at: :desc).limit(3)
        sequential_ids = invoices.pluck(:sequential_id)
        organization_sequential_ids = invoices.pluck(:organization_sequential_id)
        billing_entity_sequential_ids = invoices.pluck(:billing_entity_sequential_id)
        numbers = organization.reload.invoices.order(created_at: :desc).pluck(:number)

        expect(sequential_ids).to match_array([3, nil, 2])
        expect(organization_sequential_ids).to match_array([0, 0, 0])
        expect(billing_entity_sequential_ids).to match_array([nil, nil, nil])
        expect(numbers)
          .to match_array(
            %w[
              BENT-1-001-001
              BENT-1-002-001
              BENT-1-003-001
              BENT-1-001-002
              BENT-1-002-002
              BENT-1-001-003
              BENT-1-DRAFT
              BENT-1-003-002
            ]
          )
      end

      # NOTE: September 19th: Bill subscription
      travel_to(DateTime.new(2023, 9, 19, 12, 12)) do
        perform_billing

        invoices = organization.invoices.order(created_at: :desc).limit(3)
        sequential_ids = invoices.pluck(:sequential_id)
        organization_sequential_ids = invoices.pluck(:organization_sequential_id)
        billing_entity_sequential_ids = invoices.pluck(:billing_entity_sequential_id)
        numbers = organization.reload.invoices.order(created_at: :desc).pluck(:number)

        expect(sequential_ids).to match_array([4, nil, 3])
        expect(organization_sequential_ids).to match_array([0, 0, 0])
        expect(billing_entity_sequential_ids).to match_array([nil, nil, nil])
        expect(numbers)
          .to match_array(
            %w[
              BENT-1-001-001
              BENT-1-002-001
              BENT-1-003-001
              BENT-1-001-002
              BENT-1-002-002
              BENT-1-001-003
              BENT-1-DRAFT
              BENT-1-003-002
              BENT-1-001-004
              BENT-1-DRAFT
              BENT-1-003-003
            ]
          )
      end
    end
  end

  context "with grace period and per billing entity numbering" do
    let(:customer_second) { create(:customer, organization:, invoice_grace_period: 2) }

    let(:organization) do
      create(
        :organization,
        document_numbering: "per_organization",
        document_number_prefix: "ORG-1",
        webhook_url: nil
      )
    end

    let(:billing_entity_first) do
      create(
        :billing_entity,
        organization:,
        document_numbering: "per_billing_entity",
        document_number_prefix: "BENT-1",
        timezone: "Europe/Paris",
        email_settings: []
      )
    end

    it "creates invoice numbers correctly" do
      # NOTE: Jul 19th: create the subscription
      travel_to(subscription_at) do
        create_subscription(
          {
            external_customer_id: customer_first.external_id,
            external_id: customer_first.external_id,
            plan_code: monthly_plan.code,
            billing_time: "anniversary",
            subscription_at: subscription_at.iso8601
          }
        )
        create_subscription(
          {
            external_customer_id: customer_second.external_id,
            external_id: customer_second.external_id,
            plan_code: monthly_plan.code,
            billing_time: "anniversary",
            subscription_at: subscription_at.iso8601
          }
        )
        create_subscription(
          {
            external_customer_id: customer_third.external_id,
            external_id: customer_third.external_id,
            plan_code: monthly_plan.code,
            billing_time: "anniversary",
            subscription_at: subscription_at.iso8601
          }
        )

        invoices = organization.invoices.order(created_at: :desc).limit(3)
        sequential_ids = invoices.pluck(:sequential_id)
        organization_sequential_ids = invoices.pluck(:organization_sequential_id)
        billing_entity_sequential_ids = invoices.pluck(:billing_entity_sequential_id)
        numbers = invoices.pluck(:number)

        expect(sequential_ids).to match_array([1, nil, 1])
        # we won't be filling organization_sequential_id as soon as we switch to per_billing_entity numbering
        expect(organization_sequential_ids).to match_array([0, 0, 0])
        expect(billing_entity_sequential_ids).to match_array([1, nil, 2])
        expect(numbers).to match_array(%w[BENT-1-202307-001 BENT-1-DRAFT BENT-1-202307-002])
      end

      # NOTE: Jul 20th: New subscription for the first customer
      time = subscription_at + 1.day
      travel_to(time) do
        create_subscription(
          {
            external_customer_id: customer_first.external_id,
            external_id: "new_external_id",
            plan_code: yearly_plan.code,
            billing_time: "anniversary",
            subscription_at: time.iso8601
          }
        )

        invoices = organization.reload.invoices.order(created_at: :desc)

        expect(invoices.first.sequential_id).to eq(2)
        # we won't be filling organization_sequential_id as soon as we switch to per_billing_entity numbering
        expect(invoices.first.organization_sequential_id).to eq(0)
        expect(invoices.first.billing_entity_sequential_id).to eq(3)
        expect(invoices.pluck(:number))
          .to match_array(
            %w[
              BENT-1-202307-001
              BENT-1-DRAFT
              BENT-1-202307-002
              BENT-1-202307-003
            ]
          )
      end

      # NOTE: Jul 21st: New subscription for the second customer
      time = subscription_at + 2.days
      travel_to(time) do
        create_subscription(
          {
            external_customer_id: customer_second.external_id,
            external_id: "new_external_id_2",
            plan_code: yearly_plan.code,
            billing_time: "anniversary",
            subscription_at: time.iso8601
          }
        )

        invoices = organization.reload.invoices.order(created_at: :desc)

        expect(invoices.first.sequential_id).to be_nil
        expect(invoices.first.organization_sequential_id).to be_zero
        expect(invoices.first.billing_entity_sequential_id).to be_nil
        expect(invoices.pluck(:number))
          .to match_array(
            %w[
              BENT-1-202307-001
              BENT-1-DRAFT
              BENT-1-202307-002
              BENT-1-202307-003
              BENT-1-DRAFT
            ]
          )
      end

      travel_to(time + 1.hour) do
        draft_invoice1 = customer_second.reload.invoices.draft.order(created_at: :asc).first

        finalize_invoice(draft_invoice1)

        invoices = organization.reload.invoices.order(created_at: :desc)

        expect(invoices.pluck(:number))
          .to match_array(
            %w[
              BENT-1-202307-001
              BENT-1-202307-004
              BENT-1-202307-002
              BENT-1-202307-003
              BENT-1-DRAFT
            ]
          )
      end

      travel_to(time + 2.hours) do
        draft_invoice2 = customer_second.reload.invoices.draft.order(created_at: :asc).last

        finalize_invoice(draft_invoice2)

        invoices = organization.reload.invoices.order(created_at: :desc)

        expect(invoices.pluck(:number))
          .to match_array(
            %w[
              BENT-1-202307-001
              BENT-1-202307-004
              BENT-1-202307-002
              BENT-1-202307-003
              BENT-1-202307-005
            ]
          )
      end

      # NOTE: August 19th: Bill subscription
      travel_to(DateTime.new(2023, 8, 19, 12, 12)) do
        perform_billing

        invoices = organization.invoices.order(created_at: :desc).limit(3)
        sequential_ids = invoices.pluck(:sequential_id)
        organization_sequential_ids = invoices.pluck(:organization_sequential_id)
        billing_entity_sequential_ids = invoices.pluck(:billing_entity_sequential_id)
        numbers = organization.reload.invoices.order(created_at: :desc).pluck(:number)

        expect(sequential_ids).to match_array([3, nil, 2])
        # we won't be filling organization_sequential_id as soon as we switch to per_billing_entity numbering
        expect(organization_sequential_ids).to match_array([0, 0, 0])
        expect(billing_entity_sequential_ids).to match_array([6, nil, 7])
        expect(numbers)
          .to match_array(
            %w[
              BENT-1-202307-001
              BENT-1-202307-004
              BENT-1-202307-002
              BENT-1-202307-003
              BENT-1-202307-005
              BENT-1-202308-006
              BENT-1-DRAFT
              BENT-1-202308-007
            ]
          )
      end

      # NOTE: September 19th: Bill subscription
      travel_to(DateTime.new(2023, 9, 19, 12, 12)) do
        perform_billing

        invoices = organization.invoices.order(created_at: :desc).limit(3)
        sequential_ids = invoices.pluck(:sequential_id)
        organization_sequential_ids = invoices.pluck(:organization_sequential_id)
        billing_entity_sequential_ids = invoices.pluck(:billing_entity_sequential_id)
        numbers = organization.reload.invoices.order(created_at: :desc).pluck(:number)

        expect(sequential_ids).to match_array([4, nil, 3])
        # we won't be filling organization_sequential_id as soon as we switch to per_billing_entity numbering
        expect(organization_sequential_ids).to match_array([0, 0, 0])
        expect(billing_entity_sequential_ids).to match_array([8, nil, 9])
        expect(numbers)
          .to match_array(
            %w[
              BENT-1-202307-001
              BENT-1-202307-004
              BENT-1-202307-002
              BENT-1-202307-003
              BENT-1-202307-005
              BENT-1-202308-006
              BENT-1-DRAFT
              BENT-1-202308-007
              BENT-1-202309-008
              BENT-1-DRAFT
              BENT-1-202309-009
            ]
          )
      end

      travel_to(DateTime.new(2023, 9, 20, 12, 12)) do
        draft_invoice1 = customer_second.reload.invoices.draft.order(created_at: :asc).first

        finalize_invoice(draft_invoice1)

        invoices = organization.reload.invoices.order(created_at: :desc)

        expect(invoices.pluck(:number))
          .to match_array(
            %w[
              BENT-1-202307-001
              BENT-1-202307-004
              BENT-1-202307-002
              BENT-1-202307-003
              BENT-1-202307-005
              BENT-1-202308-006
              BENT-1-202309-010
              BENT-1-202308-007
              BENT-1-202309-008
              BENT-1-DRAFT
              BENT-1-202309-009
            ]
          )
      end
    end
  end

  context "with partner customer", :premium do
    let(:customer_third) { create(:customer, organization:, billing_entity: billing_entity_first, account_type: "partner") }

    before { organization.update!(premium_integrations: ["revenue_share"]) }

    it "creates invoice numbers correctly" do
      # NOTE: Jul 19th: create the subscription
      travel_to(subscription_at) do
        create_subscription(
          {
            external_customer_id: customer_first.external_id,
            external_id: customer_first.external_id,
            plan_code: monthly_plan.code,
            billing_time: "anniversary",
            subscription_at: subscription_at.iso8601
          }
        )
        create_subscription(
          {
            external_customer_id: customer_second.external_id,
            external_id: customer_second.external_id,
            plan_code: monthly_plan.code,
            billing_time: "anniversary",
            subscription_at: subscription_at.iso8601
          }
        )
        create_subscription(
          {
            external_customer_id: customer_third.external_id,
            external_id: customer_third.external_id,
            plan_code: monthly_plan.code,
            billing_time: "anniversary",
            subscription_at: subscription_at.iso8601
          }
        )

        invoices = organization.invoices.order(created_at: :desc).limit(3)
        sequential_ids = invoices.pluck(:sequential_id)
        organization_sequential_ids = invoices.pluck(:organization_sequential_id)
        billing_entity_sequential_ids = invoices.pluck(:billing_entity_sequential_id)
        numbers = invoices.pluck(:number)

        expect(sequential_ids).to match_array([1, 1, 1])
        expect(organization_sequential_ids).to match_array([0, 0, 0])
        expect(billing_entity_sequential_ids).to match_array([nil, nil, nil])
        expect(numbers).to match_array(%w[BENT-1-001-001 BENT-1-002-001 BENT-1-003-001])
      end

      # NOTE: August 19th: Bill subscription
      travel_to(DateTime.new(2023, 8, 19, 12, 12)) do
        perform_billing

        invoices = organization.invoices.order(created_at: :desc).limit(3)
        sequential_ids = invoices.pluck(:sequential_id)
        organization_sequential_ids = invoices.pluck(:organization_sequential_id)
        billing_entity_sequential_ids = invoices.pluck(:billing_entity_sequential_id)
        numbers = invoices.pluck(:number)

        expect(sequential_ids).to match_array([2, 2, 2])
        expect(organization_sequential_ids).to match_array([0, 0, 0])
        expect(billing_entity_sequential_ids).to match_array([nil, nil, nil])
        expect(numbers).to match_array(%w[BENT-1-001-002 BENT-1-002-002 BENT-1-003-002])
      end

      # NOTE: September 19th: Bill subscription
      travel_to(DateTime.new(2023, 9, 19, 12, 12)) do
        perform_billing

        invoices = organization.invoices.order(created_at: :desc).limit(3)
        sequential_ids = invoices.pluck(:sequential_id)
        organization_sequential_ids = invoices.pluck(:organization_sequential_id)
        billing_entity_sequential_ids = invoices.pluck(:billing_entity_sequential_id)
        numbers = invoices.pluck(:number)

        expect(sequential_ids).to match_array([3, 3, 3])
        expect(organization_sequential_ids).to match_array([0, 0, 0])
        expect(billing_entity_sequential_ids).to match_array([nil, nil, nil])
        expect(numbers).to match_array(%w[BENT-1-001-003 BENT-1-002-003 BENT-1-003-003])
      end

      # NOTE: October 19th: Switching to per_organization numbering and Bill subscription
      travel_to(DateTime.new(2023, 10, 19, 12, 12)) do
        update_organization({document_numbering: "per_organization", document_number_prefix: "BENT-11"})

        perform_billing

        invoices = organization.invoices.order(created_at: :desc).limit(3)
        sequential_ids = invoices.pluck(:sequential_id)
        organization_sequential_ids = invoices.pluck(:organization_sequential_id)
        billing_entity_sequential_ids = invoices.pluck(:billing_entity_sequential_id)
        numbers = invoices.pluck(:number)

        expect(sequential_ids).to match_array([4, 4, 4])
        # we won't be filling organization_sequential_id as soon as we switch to per_billing_entity numbering
        expect(organization_sequential_ids).to match_array([0, 0, 0])
        expect(billing_entity_sequential_ids).to match_array([7, 8, nil])
        expect(numbers).to match_array(%w[BENT-11-202310-007 BENT-11-202310-008 BENT-11-003-004])
      end

      # NOTE: November 19th: Switching to per_customer numbering and Bill subscription
      travel_to(DateTime.new(2023, 11, 19, 12, 12)) do
        update_organization({document_numbering: "per_customer"})

        perform_billing

        invoices = organization.invoices.order(created_at: :desc).limit(3)
        sequential_ids = invoices.pluck(:sequential_id)
        organization_sequential_ids = invoices.pluck(:organization_sequential_id)
        billing_entity_sequential_ids = invoices.pluck(:billing_entity_sequential_id)
        numbers = invoices.pluck(:number)

        expect(sequential_ids).to match_array([5, 5, 5])
        expect(organization_sequential_ids).to match_array([0, 0, 0])
        expect(billing_entity_sequential_ids).to match_array([nil, nil, nil])
        expect(numbers).to match_array(%w[BENT-11-001-005 BENT-11-002-005 BENT-11-003-005])
      end

      # NOTE: December 19th: Switching to per_organization numbering and Bill subscription
      travel_to(DateTime.new(2023, 12, 19, 12, 12)) do
        update_organization({document_numbering: "per_organization"})

        perform_billing

        invoices = organization.invoices.order(created_at: :desc).limit(3)
        sequential_ids = invoices.pluck(:sequential_id)
        organization_sequential_ids = invoices.pluck(:organization_sequential_id)
        billing_entity_sequential_ids = invoices.pluck(:billing_entity_sequential_id)
        numbers = invoices.pluck(:number)

        expect(sequential_ids).to match_array([6, 6, 6])
        # we won't be filling organization_sequential_id as soon as we switch to per_billing_entity numbering
        expect(organization_sequential_ids).to match_array([0, 0, 0])
        expect(billing_entity_sequential_ids).to match_array([11, 12, nil])
        expect(numbers).to match_array(%w[BENT-11-202312-011 BENT-11-202312-012 BENT-11-003-006])
      end
    end
  end

  context "with multiple billing entities" do
    let(:organization) do
      create(
        :organization,
        document_numbering: "per_customer",
        billing_entities: [billing_entity_first, billing_entity_second]
      )
    end

    let(:billing_entity_first) do
      create(:billing_entity, document_numbering: "per_customer", document_number_prefix: "BENT-1")
    end

    let(:billing_entity_second) do
      create(:billing_entity, document_numbering: "per_customer", document_number_prefix: "BENT-2")
    end

    let(:customer_fourth) { create(:customer, organization:, billing_entity: billing_entity_second) }
    let(:customer_fifth) { create(:customer, organization:, billing_entity: billing_entity_second) }

    it "creates invoice numbers correctly" do
      # NOTE: Jul 19th: create the subscriptions
      travel_to(subscription_at) do
        # First billing entity customers
        create_subscription(
          {
            external_customer_id: customer_first.external_id,
            external_id: customer_first.external_id,
            plan_code: monthly_plan.code,
            billing_time: "anniversary",
            subscription_at: subscription_at.iso8601
          }
        )
        create_subscription(
          {
            external_customer_id: customer_second.external_id,
            external_id: customer_second.external_id,
            plan_code: monthly_plan.code,
            billing_time: "anniversary",
            subscription_at: subscription_at.iso8601
          }
        )
        create_subscription(
          {
            external_customer_id: customer_third.external_id,
            external_id: customer_third.external_id,
            plan_code: monthly_plan.code,
            billing_time: "anniversary",
            subscription_at: subscription_at.iso8601
          }
        )

        # Second billing entity customers
        create_subscription(
          {
            external_customer_id: customer_fourth.external_id,
            external_id: customer_fourth.external_id,
            plan_code: monthly_plan.code,
            billing_time: "anniversary",
            subscription_at: subscription_at.iso8601
          }
        )
        create_subscription(
          {
            external_customer_id: customer_fifth.external_id,
            external_id: customer_fifth.external_id,
            plan_code: monthly_plan.code,
            billing_time: "anniversary",
            subscription_at: subscription_at.iso8601
          }
        )

        invoices = organization.invoices.order(created_at: :desc).limit(5)
        sequential_ids = invoices.pluck(:sequential_id)
        organization_sequential_ids = invoices.pluck(:organization_sequential_id)
        billing_entity_sequential_ids = invoices.pluck(:billing_entity_sequential_id)
        numbers = invoices.pluck(:number)

        expect(sequential_ids).to match_array([1, 1, 1, 1, 1])
        expect(organization_sequential_ids).to match_array([0, 0, 0, 0, 0])
        expect(billing_entity_sequential_ids).to match_array([nil, nil, nil, nil, nil])
        expect(numbers).to match_array(%w[BENT-1-001-001 BENT-1-002-001 BENT-1-003-001 BENT-2-004-001 BENT-2-005-001])
      end

      # NOTE: August 19th: Bill subscriptions
      travel_to(DateTime.new(2023, 8, 19, 12, 12)) do
        perform_billing

        invoices = organization.invoices.order(created_at: :desc).limit(5)
        sequential_ids = invoices.pluck(:sequential_id)
        organization_sequential_ids = invoices.pluck(:organization_sequential_id)
        billing_entity_sequential_ids = invoices.pluck(:billing_entity_sequential_id)
        numbers = invoices.pluck(:number)

        expect(sequential_ids).to match_array([2, 2, 2, 2, 2])
        expect(organization_sequential_ids).to match_array([0, 0, 0, 0, 0])
        expect(billing_entity_sequential_ids).to match_array([nil, nil, nil, nil, nil])
        expect(numbers).to match_array(%w[BENT-1-001-002 BENT-1-002-002 BENT-1-003-002 BENT-2-004-002 BENT-2-005-002])
      end

      # NOTE: September 19th: Bill subscriptions
      travel_to(DateTime.new(2023, 9, 19, 12, 12)) do
        perform_billing

        invoices = organization.invoices.order(created_at: :desc).limit(5)
        sequential_ids = invoices.pluck(:sequential_id)
        organization_sequential_ids = invoices.pluck(:organization_sequential_id)
        billing_entity_sequential_ids = invoices.pluck(:billing_entity_sequential_id)
        numbers = invoices.pluck(:number)

        expect(sequential_ids).to match_array([3, 3, 3, 3, 3])
        expect(organization_sequential_ids).to match_array([0, 0, 0, 0, 0])
        expect(billing_entity_sequential_ids).to match_array([nil, nil, nil, nil, nil])
        expect(numbers).to match_array(%w[BENT-1-001-003 BENT-1-002-003 BENT-1-003-003 BENT-2-004-003 BENT-2-005-003])
      end

      # NOTE: October 19th: Switching 1st billing entity to per_billing_entity numbering and Bill subscriptions
      travel_to(DateTime.new(2023, 10, 19, 12, 12)) do
        # TODO: the endpoint to update the billing entity is not available yet,
        #       updating organzation document_numbering to "per_organization"
        #       will update organization's default billing entity document_numbering
        #       to "per_billing_entity".
        update_organization({document_numbering: "per_organization", document_number_prefix: "ORG-99"})
        update_billing_entity(billing_entity_first, {document_numbering: "per_billing_entity", document_number_prefix: "BENT-11"})

        perform_billing

        invoices = organization.invoices.order(created_at: :desc).limit(5)
        sequential_ids = invoices.pluck(:sequential_id)
        organization_sequential_ids = invoices.pluck(:organization_sequential_id)
        billing_entity_sequential_ids = invoices.pluck(:billing_entity_sequential_id)
        numbers = invoices.pluck(:number)

        expect(sequential_ids).to match_array([4, 4, 4, 4, 4])
        # we won't be filling organization_sequential_id as soon as we switch to per_billing_entity numbering
        expect(organization_sequential_ids).to match_array([0, 0, 0, 0, 0])
        expect(billing_entity_sequential_ids).to match_array([10, 11, 12, nil, nil])
        expect(numbers).to match_array(%w[BENT-11-202310-010 BENT-11-202310-011 BENT-11-202310-012 BENT-2-004-004 BENT-2-005-004])
      end

      # NOTE: November 19th: Switching 2nd billing entity to per_biling_entity numbering and Bill subscriptions
      travel_to(DateTime.new(2023, 11, 19, 12, 12)) do
        update_billing_entity(billing_entity_second, document_numbering: "per_billing_entity", document_number_prefix: "BENT-22")

        perform_billing

        invoices = organization.invoices.order(created_at: :desc).limit(5)
        sequential_ids = invoices.pluck(:sequential_id)
        organization_sequential_ids = invoices.pluck(:organization_sequential_id)
        billing_entity_sequential_ids = invoices.pluck(:billing_entity_sequential_id)
        numbers = invoices.pluck(:number)

        expect(sequential_ids).to match_array([5, 5, 5, 5, 5])
        # we won't be filling organization_sequential_id as soon as we switch to per_billing_entity numbering
        expect(organization_sequential_ids).to match_array([0, 0, 0, 0, 0])
        expect(billing_entity_sequential_ids).to match_array([13, 14, 15, 9, 10])
        expect(numbers).to match_array(%w[BENT-11-202311-013 BENT-11-202311-014 BENT-11-202311-015 BENT-22-202311-009 BENT-22-202311-010])
      end

      # NOTE: December 19th: Switching all to per_customer numbering and Bill subscriptions
      travel_to(DateTime.new(2023, 12, 19, 12, 12)) do
        # TODO: the endpoint to update the billing entity is not available yet,
        #       updating organzation document_numbering to "per_customer"
        #       will update organization's default billing entity document_numbering
        #       to "per_customer".
        update_organization({document_numbering: "per_customer"})
        update_billing_entity(billing_entity_second, {document_numbering: "per_customer"})

        perform_billing

        invoices = organization.invoices.order(created_at: :desc).limit(5)
        sequential_ids = invoices.pluck(:sequential_id)
        organization_sequential_ids = invoices.pluck(:organization_sequential_id)
        billing_entity_sequential_ids = invoices.pluck(:billing_entity_sequential_id)
        numbers = invoices.pluck(:number)

        expect(sequential_ids).to match_array([6, 6, 6, 6, 6])
        expect(organization_sequential_ids).to match_array([0, 0, 0, 0, 0])
        expect(billing_entity_sequential_ids).to match_array([nil, nil, nil, nil, nil])
        expect(numbers).to match_array(%w[BENT-11-001-006 BENT-11-002-006 BENT-11-003-006 BENT-22-004-006 BENT-22-005-006])
      end

      # NOTE: January 19th 2024: Switching all to per_billing_entity numbering and Bill subscriptions
      travel_to(DateTime.new(2024, 1, 19, 12, 12)) do
        # TODO: the endpoint to update the billing entity is not available yet,
        #       updating organzation document_numbering to "per_organization"
        #       will update organization's default billing entity document_numbering
        #       to "per_billing_entity".
        update_organization({document_numbering: "per_organization"})
        update_billing_entity(billing_entity_first, {document_numbering: "per_billing_entity"})
        update_billing_entity(billing_entity_second, {document_numbering: "per_billing_entity"})

        perform_billing

        invoices = organization.invoices.order(created_at: :desc).limit(5)
        sequential_ids = invoices.pluck(:sequential_id)
        organization_sequential_ids = invoices.pluck(:organization_sequential_id)
        billing_entity_sequential_ids = invoices.pluck(:billing_entity_sequential_id)
        numbers = invoices.pluck(:number)

        expect(sequential_ids).to match_array([7, 7, 7, 7, 7])
        # we won't be filling organization_sequential_id as soon as we switch to per_billing_entity numbering
        expect(organization_sequential_ids).to match_array([0, 0, 0, 0, 0])
        expect(billing_entity_sequential_ids).to match_array([19, 20, 21, 13, 14])
        expect(numbers).to match_array(%w[BENT-11-202401-019 BENT-11-202401-020 BENT-11-202401-021 BENT-22-202401-013 BENT-22-202401-014])
      end
    end
  end

  context "with a single customer billed across multiple billing entities" do
    let(:organization) do
      create(
        :organization,
        document_numbering: "per_customer",
        webhook_url: nil,
        billing_entities: [billing_entity_first, billing_entity_second]
      )
    end

    let(:billing_entity_first) do
      create(:billing_entity, document_numbering: "per_customer", document_number_prefix: "BENT-1")
    end

    let(:billing_entity_second) do
      create(:billing_entity, document_numbering: "per_customer", document_number_prefix: "BENT-2")
    end

    let(:customer) { create(:customer, organization:, billing_entity: billing_entity_first) }
    let(:subscription_under_first_external_id) { "sub-under-first" }
    let(:subscription_under_second_external_id) { "sub-under-second" }

    before { organization.enable_feature_flag!(:multi_entity_billing) }

    it "numbers invoices gaplessly per (customer, billing_entity)" do
      # NOTE: Jul 19th: create two subscriptions for the same customer, one per billing entity
      travel_to(subscription_at) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: subscription_under_first_external_id,
            plan_code: monthly_plan.code,
            billing_time: "anniversary",
            subscription_at: subscription_at.iso8601
          }
        )
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: subscription_under_second_external_id,
            plan_code: monthly_plan.code,
            billing_time: "anniversary",
            subscription_at: subscription_at.iso8601,
            billing_entity_code: billing_entity_second.code
          }
        )

        invoices = customer.reload.invoices

        expect(invoices.where(billing_entity: billing_entity_first).pluck(:sequential_id)).to eq([1])
        expect(invoices.where(billing_entity: billing_entity_second).pluck(:sequential_id)).to eq([1])
        expect(invoices.pluck(:number))
          .to match_array(%w[BENT-1-001-001 BENT-2-001-001])
      end

      # NOTE: August 19th: second billing cycle
      travel_to(DateTime.new(2023, 8, 19, 12, 12)) do
        perform_billing

        invoices = customer.reload.invoices.order(created_at: :asc)

        expect(invoices.where(billing_entity: billing_entity_first).pluck(:sequential_id))
          .to eq([1, 2])
        expect(invoices.where(billing_entity: billing_entity_second).pluck(:sequential_id))
          .to eq([1, 2])
        expect(invoices.pluck(:number))
          .to match_array(
            %w[
              BENT-1-001-001
              BENT-2-001-001
              BENT-1-001-002
              BENT-2-001-002
            ]
          )
      end

      # NOTE: September 19th: third billing cycle — sequences stay gapless and independent per entity
      travel_to(DateTime.new(2023, 9, 19, 12, 12)) do
        perform_billing

        invoices = customer.reload.invoices.order(created_at: :asc)

        expect(invoices.where(billing_entity: billing_entity_first).pluck(:sequential_id))
          .to eq([1, 2, 3])
        expect(invoices.where(billing_entity: billing_entity_second).pluck(:sequential_id))
          .to eq([1, 2, 3])
        expect(invoices.pluck(:number))
          .to match_array(
            %w[
              BENT-1-001-001
              BENT-2-001-001
              BENT-1-001-002
              BENT-2-001-002
              BENT-1-001-003
              BENT-2-001-003
            ]
          )
      end
    end
  end
end
