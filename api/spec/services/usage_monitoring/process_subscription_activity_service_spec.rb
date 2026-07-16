# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsageMonitoring::ProcessSubscriptionActivityService, :premium do
  subject(:service) { described_class.new(subscription_activity:) }

  let(:organization) { create(:organization, premium_integrations:) }
  let(:mocked_current_usage) { double("current_usage") } # rubocop:disable RSpec/VerifiedDoubles
  let(:customer) { create(:customer, organization:) }
  let(:subscription) { create(:subscription, customer:) }
  let(:subscription_activity) { create(:subscription_activity, subscription:, organization:) }

  before do
    subscription_activity
    allow(::Invoices::CustomerUsageService).to receive(:call)
      .and_return(double(usage: mocked_current_usage)) # rubocop:disable RSpec/VerifiedDoubles
    allow(LifetimeUsages::CalculateService).to receive(:call!)
    allow(LifetimeUsages::CheckThresholdsService).to receive(:call!)
  end

  context "when both lifetime_usage and progressive_billing are enabled" do
    let(:premium_integrations) { %w[lifetime_usage progressive_billing] }

    it "calls both services and deletes subscription_activity" do
      result = service.call

      expect(LifetimeUsages::CalculateService).to have_received(:call!).with(
        lifetime_usage: subscription.lifetime_usage || an_instance_of(LifetimeUsage),
        current_usage: mocked_current_usage
      )
      expect(LifetimeUsages::CheckThresholdsService).to have_received(:call!).with(
        lifetime_usage: subscription.lifetime_usage || an_instance_of(LifetimeUsage)
      )

      expect(result).to be_success
      expect { subscription_activity.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  context "when lifetime_usage and progressive_billing are both disabled" do
    let(:premium_integrations) { ["salesforce"] }

    it "calculates and checks thresholds are not called" do
      result = service.call

      expect(LifetimeUsages::CalculateService).not_to have_received(:call!)
      expect(LifetimeUsages::CheckThresholdsService).not_to have_received(:call!)

      expect(result).to be_success
      expect { subscription_activity.reload }.to raise_error(ActiveRecord::RecordNotFound) # deleted
    end

    it "creates a lifetime usage if does not exist" do
      subscription.lifetime_usage&.delete
      expect { service.call }.to change { subscription.reload.lifetime_usage.present? }.from(false).to(true)
    end
  end

  context "when only using lifetime_usage" do
    let(:premium_integrations) { ["lifetime_usage"] }

    it "calls calculate service and deletes subscription_activity" do
      result = service.call

      expect(LifetimeUsages::CalculateService).to have_received(:call!).with(
        lifetime_usage: subscription.lifetime_usage || an_instance_of(LifetimeUsage),
        current_usage: mocked_current_usage
      )
      expect(LifetimeUsages::CheckThresholdsService).not_to have_received(:call!)

      expect(result).to be_success
      expect { subscription_activity.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  context "when progressive_billing_enabled is true" do
    let(:premium_integrations) { ["progressive_billing"] }

    it "calls both calculate and check thresholds services and deletes subscription_activity" do
      result = service.call

      expect(LifetimeUsages::CalculateService).to have_received(:call!).with(
        lifetime_usage: subscription.lifetime_usage || an_instance_of(LifetimeUsage),
        current_usage: mocked_current_usage
      )
      expect(LifetimeUsages::CheckThresholdsService).to have_received(:call!).with(
        lifetime_usage: subscription.lifetime_usage || an_instance_of(LifetimeUsage)
      )

      expect(result).to be_success
      expect { subscription_activity.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  context "when lifetime_usage already exists" do
    let(:premium_integrations) { %w[progressive_billing] }

    it "does not create a new lifetime usage" do
      create(:lifetime_usage, subscription: subscription, organization: organization)
      expect { service.call }.not_to change(LifetimeUsage, :count)
    end
  end

  context "when subscription has alerts" do
    let(:premium_integrations) { [] }
    let(:billable_metric) { create(:billable_metric, organization:) }
    let(:alert) { create(:usage_current_amount_alert, organization:, subscription_external_id: subscription.external_id) }
    let(:alert_2) { create(:billable_metric_current_usage_amount_alert, billable_metric:, organization:, subscription_external_id: subscription.external_id) }
    let(:alert_3) { create(:billable_metric_current_usage_units_alert, billable_metric:, organization:, subscription_external_id: subscription.external_id) }
    let(:alert_4) { create(:lifetime_usage_amount_alert, organization:, subscription_external_id: subscription.external_id) }

    before do
      alert
      alert_2
      alert_3
      alert_4
      allow(::UsageMonitoring::ProcessAlertService).to receive(:call)
    end

    it "processes the alerts" do
      service.call
      expect(::UsageMonitoring::ProcessAlertService).to have_received(:call).exactly(4).times
      expect(::UsageMonitoring::ProcessAlertService).to have_received(:call).with(alert: alert, alertable: subscription, current_metrics: mocked_current_usage)
      expect(::UsageMonitoring::ProcessAlertService).to have_received(:call).with(alert: alert_2, alertable: subscription, current_metrics: mocked_current_usage)
      expect(::UsageMonitoring::ProcessAlertService).to have_received(:call).with(alert: alert_3, alertable: subscription, current_metrics: mocked_current_usage)
      expect(::UsageMonitoring::ProcessAlertService).to have_received(:call).with(alert: alert_4, alertable: subscription, current_metrics: subscription.lifetime_usage)
      expect { subscription_activity.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    context "when alerting fail" do
      it "deletes subscription_activity before raising" do
        allow(::UsageMonitoring::ProcessAlertService).to receive(:call).and_raise(StandardError, "boom")
        expect { service.call }.to raise_error(StandardError, "boom")
        expect { subscription_activity.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when one alert fails" do
      it "still processes the other alerts and raises the first error" do
        allow(::UsageMonitoring::ProcessAlertService).to receive(:call).and_call_original
        allow(::UsageMonitoring::ProcessAlertService).to receive(:call)
          .with(alert: alert, alertable: subscription, current_metrics: mocked_current_usage)
          .and_raise(StandardError, "first alert failed")
        allow(::UsageMonitoring::ProcessAlertService).to receive(:call)
          .with(alert: alert_2, alertable: subscription, current_metrics: mocked_current_usage)
        allow(::UsageMonitoring::ProcessAlertService).to receive(:call)
          .with(alert: alert_3, alertable: subscription, current_metrics: mocked_current_usage)
        allow(::UsageMonitoring::ProcessAlertService).to receive(:call)
          .with(alert: alert_4, alertable: subscription, current_metrics: subscription.lifetime_usage)

        expect { service.call }.to raise_error(StandardError, "first alert failed")

        expect(::UsageMonitoring::ProcessAlertService).to have_received(:call)
          .with(alert: alert_2, alertable: subscription, current_metrics: mocked_current_usage)
        expect(::UsageMonitoring::ProcessAlertService).to have_received(:call)
          .with(alert: alert_3, alertable: subscription, current_metrics: mocked_current_usage)
        expect(::UsageMonitoring::ProcessAlertService).to have_received(:call)
          .with(alert: alert_4, alertable: subscription, current_metrics: subscription.lifetime_usage)
        expect { subscription_activity.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when progressive_billing fail" do
      let(:premium_integrations) { %w[lifetime_usage progressive_billing] }

      it "processes alert and then raise" do
        allow(LifetimeUsages::CheckThresholdsService).to receive(:call!).and_raise(StandardError, "boom")
        expect { service.call }.to raise_error(StandardError, "boom")
        expect(::UsageMonitoring::ProcessAlertService).to have_received(:call).with(alert:, alertable: subscription, current_metrics: mocked_current_usage)
        expect { subscription_activity.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  context "when subscription has billable_metric_lifetime_usage_units alert" do
    let(:premium_integrations) { [] }
    let(:billable_metric) { create(:billable_metric, organization:) }
    let(:charge) { create(:standard_charge, billable_metric:, plan: subscription.plan) }
    let(:alert_5) do
      create(:billable_metric_lifetime_usage_units_alert,
        billable_metric:, organization:, subscription_external_id: subscription.external_id)
    end

    let(:job_proxy) { instance_double(ActiveJob::ConfiguredJob) }

    before do
      charge
      alert_5
      allow(UsageMonitoring::ProcessLifetimeUsageAlertJob).to receive(:set).with(wait: 5.minutes).and_return(job_proxy)
      allow(job_proxy).to receive(:perform_later)
    end

    it "enqueues ProcessLifetimeUsageAlertJob with a 5 minute delay" do
      service.call

      expect(job_proxy).to have_received(:perform_later).with(alert: alert_5, subscription:)
      expect { subscription_activity.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    context "when the job enqueue raises" do
      before do
        allow(job_proxy).to receive(:perform_later).and_raise(StandardError, "enqueue failed")
      end

      it "deletes subscription_activity before raising" do
        expect { service.call }.to raise_error(StandardError, "enqueue failed")
        expect { subscription_activity.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
