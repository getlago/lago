# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::DatesService do
  subject(:date_service) { described_class.new(subscription, billing_date, false) }

  let(:subscription) do
    create(
      :subscription,
      plan:,
      subscription_at:,
      billing_time: :anniversary,
      started_at:
    )
  end

  let(:plan) { create(:plan, interval:, pay_in_advance:) }
  let(:pay_in_advance) { false }

  let(:subscription_at) { DateTime.parse("02 Feb 2021") }
  let(:billing_date) { Time.zone.parse("2022-03-07 04:20:46.011") }
  let(:started_at) { subscription_at }
  let(:interval) { :monthly }

  describe "#instance" do
    let(:result) { described_class.new_instance(subscription, billing_date) }

    context "when interval is weekly" do
      let(:interval) { :weekly }

      it "returns a weekly service instance" do
        expect(result).to be_a(Subscriptions::Dates::WeeklyService)
      end
    end

    context "when interval is quarterly" do
      let(:interval) { :quarterly }

      it "returns a quarterly service instance" do
        expect(result).to be_a(Subscriptions::Dates::QuarterlyService)
      end
    end

    context "when interval is monthly" do
      let(:interval) { :monthly }

      it "returns a monthly service instance" do
        expect(result).to be_a(Subscriptions::Dates::MonthlyService)
      end
    end

    context "when interval is yearly" do
      let(:interval) { :yearly }

      it "returns a yearly service instance" do
        expect(result).to be_a(Subscriptions::Dates::YearlyService)
      end
    end

    context "when interval is semiannual" do
      let(:interval) { :semiannual }

      it "returns a semiannual service instance" do
        expect(result).to be_a(Subscriptions::Dates::SemiannualService)
      end
    end

    context "when interval is invalid" do
      let(:interval) { :weekly }

      before do
        allow(plan).to receive(:interval).and_return(:foo)
      end

      it "raises a not implemented error" do
        expect { result }.to raise_error(NotImplementedError)

        expect(plan).to have_received(:interval)
      end
    end
  end

  describe "from_datetime" do
    it "raises a not implemented error" do
      expect { date_service.from_datetime }
        .to raise_error(NotImplementedError)
    end
  end

  describe "to_datetime" do
    it "raises a not implemented error" do
      expect { date_service.to_datetime }
        .to raise_error(NotImplementedError)
    end
  end

  describe "charges_from_datetime" do
    it "raises a not implemented error" do
      expect { date_service.charges_from_datetime }
        .to raise_error(NotImplementedError)
    end
  end

  describe "charges_to_datetime" do
    it "raises a not implemented error" do
      expect { date_service.charges_to_datetime }
        .to raise_error(NotImplementedError)
    end
  end

  describe "fixed_charges_from_datetime" do
    it "raises a not implemented error" do
      expect { date_service.fixed_charges_from_datetime }
        .to raise_error(NotImplementedError)
    end
  end

  describe "fixed_charges_to_datetime" do
    it "raises a not implemented error" do
      expect { date_service.fixed_charges_to_datetime }
        .to raise_error(NotImplementedError)
    end
  end

  describe "next_end_of_period" do
    it "raises a not implemented error" do
      expect { date_service.next_end_of_period }
        .to raise_error(NotImplementedError)
    end
  end

  describe "previous_beginning_of_period" do
    it "raises a not implemented error" do
      expect { date_service.previous_beginning_of_period }
        .to raise_error(NotImplementedError)
    end
  end

  describe "charges_duration_in_days" do
    it "raises a not implemented error" do
      expect { date_service.charges_duration_in_days }
        .to raise_error(NotImplementedError)
    end
  end

  describe "fixed_charges_duration_in_days" do
    it "raises a not implemented error" do
      expect { date_service.fixed_charges_duration_in_days }
        .to raise_error(NotImplementedError)
    end
  end

  describe ".fixed_charge_pay_in_advance_interval" do
    let(:timestamp) { Time.zone.parse("2022-03-07 04:20:46.011").to_i }
    let(:result) { described_class.fixed_charge_pay_in_advance_interval(timestamp, subscription) }
    # subscription is anniversary, subscription_at is 02 Feb 2021, Tuesday

    context "when interval is monthly" do
      let(:interval) { :monthly }

      it "returns the correct fixed charge interval data" do
        expect(result).to include(
          fixed_charges_from_datetime: Time.parse("2022-03-02").utc.beginning_of_day,
          fixed_charges_to_datetime: Time.parse("2022-04-01").utc.end_of_day,
          fixed_charges_duration: 31
        )
      end

      it "creates a date service instance with current_usage: true" do
        allow(described_class).to receive(:new_instance).and_call_original

        result

        expect(described_class).to have_received(:new_instance)
          .with(subscription, Time.zone.at(timestamp), current_usage: true)
      end
    end

    context "when interval is yearly" do
      let(:interval) { :yearly }

      it "returns the correct fixed charge interval data" do
        expect(result).to include(
          fixed_charges_from_datetime: Time.parse("2022-02-02").utc.beginning_of_day,
          fixed_charges_to_datetime: Time.parse("2023-02-01").utc.end_of_day,
          fixed_charges_duration: 365
        )
      end
    end

    context "when interval is semiannual" do
      let(:interval) { :semiannual }

      it "returns the correct fixed charge interval data" do
        expect(result).to include(
          fixed_charges_from_datetime: Time.parse("2022-02-02").utc.beginning_of_day,
          fixed_charges_to_datetime: Time.parse("2022-08-01").utc.end_of_day,
          fixed_charges_duration: 181
        )
      end
    end

    context "when interval is quarterly" do
      let(:interval) { :quarterly }

      it "returns the correct fixed charge interval data" do
        expect(result).to include(
          fixed_charges_from_datetime: Time.parse("2022-02-02").utc.beginning_of_day,
          fixed_charges_to_datetime: Time.parse("2022-05-01").utc.end_of_day,
          fixed_charges_duration: 89
        )
      end
    end

    context "when interval is weekly" do
      let(:interval) { :weekly }

      # 2022-03-01 is Tuesday
      it "returns the correct fixed charge interval data" do
        expect(result).to include(
          fixed_charges_from_datetime: Time.parse("2022-03-01").utc.beginning_of_day,
          fixed_charges_to_datetime: Time.parse("2022-03-07").utc.end_of_day,
          fixed_charges_duration: 7
        )
      end
    end
  end
end
