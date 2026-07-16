# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::BillingDateQuery do
  subject(:result) { described_class.call(subscriptions:, timestamp:) }

  let(:subscriptions) { Subscription.where(id: subscription.id) }

  let(:billing_entity_timezone) { "UTC" }
  let(:billing_entity) { create(:billing_entity, timezone: billing_entity_timezone) }
  let(:organization) { billing_entity.organization }

  let(:interval) { :monthly }
  let(:bill_charges_monthly) { false }
  let(:bill_fixed_charges_monthly) { false }
  let(:plan) { create(:plan, organization:, interval:, bill_charges_monthly:, bill_fixed_charges_monthly:) }

  let(:customer_timezone) { nil }
  let(:customer) { create(:customer, organization:, billing_entity:, timezone: customer_timezone) }

  let(:subscription_at) { DateTime.parse("20 Feb 2021") }
  let(:billing_time) { :calendar }
  let(:timestamp) { DateTime.parse("20 Jun 2022 12:00") }
  let(:subscription) do
    create(:subscription, customer:, plan:, subscription_at:, billing_time:, started_at: DateTime.parse("10 Jun 2022"))
  end

  before { subscription }

  def selected?
    result.subscriptions.exists?(subscription.id)
  end

  describe "#call" do
    # The same billing-day matrix that validates Subscriptions::OrganizationBillingService#billable_subscriptions.
    # BillingDateQuery extracts that calendar/anniversary/timezone logic, so it must select on the exact same days.
    [
      {interval: :weekly, billing_time: :calendar, billed_on: ["20 Jun 2022", "27 Jun 2022", "04 Jul 2022"], not_billed_on: ["21 Jun 2022"]},
      {interval: :weekly, billing_time: :anniversary, billed_on: ["25 Jun 2022", "02 Jul 2022", "09 Jul 2022"], not_billed_on: ["26 Jun 2022"]},
      {interval: :monthly, billing_time: :calendar, billed_on: ["01 Jul 2022", "01 Aug 2022", "01 Sep 2022"], not_billed_on: ["02 Jul 2022"]},
      {interval: :monthly, billing_time: :anniversary, billed_on: ["20 Jun 2022", "20 Jul 2022", "20 Aug 2022"], not_billed_on: ["21 Jul 2022"]},
      # 31st day monthly subscription (month normalization)
      {
        interval: :monthly,
        billing_time: :anniversary,
        subscription_at: "31 March 2021",
        billed_on: ["28 Feb 2023", "29 Feb 2024", "30 Apr 2023", "31 Jan 2023"],
        not_billed_on: ["27 Feb 2023"]
      },
      {
        interval: :quarterly,
        billing_time: :calendar,
        billed_on: ["01 Jul 2022", "01 Oct 2022", "01 Jan 2023", "01 Apr 2030"],
        not_billed_on: ["01 Feb 2022", "01 Mar 2022", "01 Dec 2023"]
      },
      # Quarterly cycle: Aug/Nov/Feb/May
      {
        interval: :quarterly,
        billing_time: :anniversary,
        billed_on: ["20 Aug 2022", "20 Nov 2022", "20 Feb 2023", "20 May 2030"],
        not_billed_on: ["20 Sep 2022"]
      },
      # Quarterly cycle: Jan/Apr/Jul/Oct
      {
        interval: :quarterly,
        billing_time: :anniversary,
        subscription_at: "15 January 2021",
        billed_on: ["15 Jul 2022", "15 Oct 2022", "15 Jan 2023", "15 Apr 2024"]
      },
      # Quarterly cycle: Mar/Jun/Sep/Dec
      {
        interval: :quarterly,
        billing_time: :anniversary,
        subscription_at: "15 March 2021",
        billed_on: ["15 Jun 2022", "15 Sep 2022", "15 Dec 2022", "15 Mar 2023"]
      },
      # 31st day quarterly subscription (month normalization)
      {
        interval: :quarterly,
        billing_time: :anniversary,
        subscription_at: "31 May 2021",
        billed_on: ["28 Feb 2023", "29 Feb 2024", "30 Nov 2023", "31 Aug 2023"]
      },
      # 30th day quarterly subscription (month normalization)
      {
        interval: :quarterly,
        billing_time: :anniversary,
        subscription_at: "30 May 2021",
        billed_on: ["28 Feb 2023", "29 Feb 2024", "30 Nov 2023", "30 Aug 2023"],
        not_billed_on: ["31 Aug 2023"]
      },
      {
        interval: :semiannual,
        billing_time: :calendar,
        billed_on: ["01 Jul 2022", "01 Jan 2023", "01 Jul 2030"],
        not_billed_on: ["01 Oct 2022"]
      },
      {
        interval: :semiannual,
        billing_time: :anniversary,
        billed_on: ["20 Aug 2022", "20 Feb 2023", "20 Aug 2030"],
        not_billed_on: ["20 Nov 2022"]
      },
      # 31st day semiannual subscription (month normalization)
      {
        interval: :semiannual,
        billing_time: :anniversary,
        subscription_at: "31 Aug 2021",
        billed_on: ["28 Feb 2023", "29 Feb 2024", "31 Aug 2023"]
      },
      # 30th day semiannual subscription (month normalization)
      {
        interval: :semiannual,
        billing_time: :anniversary,
        subscription_at: "30 Aug 2021",
        billed_on: ["28 Feb 2023", "29 Feb 2024", "30 Aug 2023"],
        not_billed_on: ["31 Aug 2023"]
      },
      {
        interval: :semiannual,
        billing_time: :calendar,
        bill_charges_monthly: true,
        billed_on: ["01 Aug 2022"],
        not_billed_on: ["02 Aug 2022"]
      },
      {
        interval: :semiannual,
        billing_time: :anniversary,
        bill_charges_monthly: true,
        billed_on: ["20 Jul 2022"],
        not_billed_on: ["21 Jul 2022"]
      },
      # 31st day semiannual subscription with monthly charges (month normalization)
      {
        interval: :semiannual,
        billing_time: :anniversary,
        bill_charges_monthly: true,
        subscription_at: "31 Aug 2021",
        billed_on: ["28 Feb 2023", "29 Feb 2024", "30 Jun 2022", "31 Jul 2022"]
      },
      # Semiannual / yearly with monthly FIXED charges (bills monthly on the anchor day)
      {
        interval: :semiannual,
        billing_time: :calendar,
        bill_fixed_charges_monthly: true,
        billed_on: ["01 Aug 2022", "01 Sep 2022"],
        not_billed_on: ["02 Aug 2022"]
      },
      {
        interval: :semiannual,
        billing_time: :anniversary,
        bill_fixed_charges_monthly: true,
        billed_on: ["20 Jul 2022", "20 Aug 2022"],
        not_billed_on: ["21 Jul 2022"]
      },
      {
        interval: :yearly,
        billing_time: :calendar,
        billed_on: ["01 Jan 2023", "01 Jan 2024", "01 Jan 2030"],
        not_billed_on: ["01 Feb 2023", "01 Dec 2022"]
      },
      {
        interval: :yearly,
        billing_time: :anniversary,
        billed_on: ["20 Feb 2023", "20 Feb 2024", "20 Feb 2030"],
        not_billed_on: ["20 Jan 2023", "20 Mar 2023"]
      },
      # Non-leap year Feb 28 subscription
      {
        interval: :yearly,
        billing_time: :anniversary,
        subscription_at: "28 Feb 2021",
        billed_on: ["28 Feb 2023", "28 Feb 2024", "28 Feb 2030"]
      },
      # Leap year Feb 29 subscription
      {
        interval: :yearly,
        billing_time: :anniversary,
        subscription_at: "29 Feb 2020",
        billed_on: ["28 Feb 2023", "29 Feb 2024", "28 Feb 2030"]
      },
      {
        interval: :yearly,
        billing_time: :calendar,
        bill_charges_monthly: true,
        billed_on: ["01 Aug 2022", "01 Sep 2022", "01 Oct 2022"],
        not_billed_on: ["02 Aug 2022", "31 Aug 2022"]
      },
      {
        interval: :yearly,
        billing_time: :anniversary,
        bill_charges_monthly: true,
        billed_on: ["20 Jul 2022", "20 Aug 2022", "20 Sep 2022"],
        not_billed_on: ["21 Jul 2022", "19 Jul 2022"]
      },
      {
        interval: :yearly,
        billing_time: :anniversary,
        bill_fixed_charges_monthly: true,
        billed_on: ["20 Jul 2022", "20 Aug 2022"],
        not_billed_on: ["21 Jul 2022"]
      },
      {
        interval: :yearly,
        billing_time: :calendar,
        bill_fixed_charges_monthly: true,
        billed_on: ["01 Aug 2022", "01 Sep 2022", "01 Oct 2022"],
        not_billed_on: ["02 Aug 2022", "31 Aug 2022"]
      },
      # Semiannual anniversary anchored on a month divisible by 6 (exercises the MOD(month, 6) = 0
      # branch: bills in June and December).
      {
        interval: :semiannual,
        billing_time: :anniversary,
        subscription_at: "20 Jun 2021",
        billed_on: ["20 Jun 2022", "20 Dec 2022"],
        not_billed_on: ["20 Aug 2022", "20 Sep 2022"]
      }
    ].each do |test_case|
      case_subscription_at = test_case[:subscription_at] || "20 Feb 2021"
      case_interval = test_case[:interval]
      case_billing_time = test_case[:billing_time] || :calendar
      case_bcm = test_case.fetch(:bill_charges_monthly, false)
      case_bfcm = test_case.fetch(:bill_fixed_charges_monthly, false)
      case_billed_on = test_case[:billed_on].map { DateTime.parse(it) }
      case_not_billed_on = test_case.fetch(:not_billed_on, []).map { DateTime.parse(it) }

      charges_label = " with monthly charges" if case_bcm
      charges_label = " with monthly fixed charges" if case_bfcm
      describe "#{case_interval} #{case_billing_time}#{charges_label}, subscribed on #{case_subscription_at}" do
        let(:interval) { case_interval }
        let(:billing_time) { case_billing_time }
        let(:bill_charges_monthly) { case_bcm }
        let(:bill_fixed_charges_monthly) { case_bfcm }
        let(:subscription_at) { DateTime.parse(case_subscription_at) }

        case_billed_on.each do |billed_on|
          context "when on the billing day (#{billed_on.to_date})" do
            let(:timestamp) { billed_on }

            it "selects the subscription" do
              expect(selected?).to be(true)
            end
          end
        end

        case_not_billed_on.each do |not_billed_on|
          context "when on a non-billing day (#{not_billed_on.to_date})" do
            let(:timestamp) { not_billed_on }

            it "does not select the subscription" do
              expect(selected?).to be(false)
            end
          end
        end
      end
    end

    describe "timezone handling" do
      # Monthly calendar plan bills on the 1st.
      let(:interval) { :monthly }
      let(:billing_time) { :calendar }

      context "when it is not yet the billing day in the customer timezone" do
        let(:customer_timezone) { "America/Chicago" }
        let(:timestamp) { DateTime.parse("01 Jul 2022 00:30") } # still 30 Jun in Chicago

        it "does not select the subscription" do
          expect(selected?).to be(false)
        end
      end

      context "when it is the billing day in the customer timezone" do
        let(:customer_timezone) { "America/Chicago" }
        let(:timestamp) { DateTime.parse("01 Jul 2022 12:00") } # 1 Jul in Chicago

        it "selects the subscription" do
          expect(selected?).to be(true)
        end
      end

      context "when it is already past the billing day in the customer timezone" do
        let(:customer_timezone) { "Pacific/Auckland" }
        let(:timestamp) { DateTime.parse("01 Jul 2022 18:00") } # 2 Jul in Auckland

        it "does not select the subscription" do
          expect(selected?).to be(false)
        end
      end

      context "when the customer has no timezone" do
        let(:customer_timezone) { nil }
        let(:billing_entity_timezone) { "America/Chicago" }
        let(:timestamp) { DateTime.parse("01 Jul 2022 00:30") } # still 30 Jun in the billing entity tz

        it "falls back to the billing entity timezone" do
          expect(selected?).to be(false)
        end
      end
    end

    context "when the subscription does not bill on the given day" do
      let(:interval) { :monthly }
      let(:billing_time) { :calendar }
      let(:timestamp) { DateTime.parse("15 Jul 2022 12:00") }

      it "returns an empty scope" do
        expect(result.subscriptions).to be_empty
      end
    end
  end
end
