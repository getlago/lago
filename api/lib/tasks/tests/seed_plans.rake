# frozen_string_literal: true

require "faker"
require "factory_bot_rails"

namespace :tests do
  desc "creates plans with children plans - creates [<num_plans>] of parents plans and 10 children for each plan; <delete_charge_parents> decides if charges of children plans will be unlinked from parent charges"
  task :seed_plans, [:num_plans, :delete_charge_parents] => :environment do |_task, args|
    organization = Organization.find_or_create_by!(name: "Hooli")
    all_metrics = find_or_create_metrics(organization)

    delete_charge_parents = args[:delete_charge_parents] == "true"
    create_plans = (args[:num_plans] || 10).to_i
    create_plans.times do |i|
      args = build_plan_args(organization, all_metrics, i)
      result = Plans::CreateService.call(args)
      plan = result.plan
      generate_children_plans(plan, all_metrics, delete_charge_parents)
    end
  end
end

def find_or_create_metrics(organization)
  metrics_params = [
    {name: "metered_count", agg_type: :count_agg, recurring: false},
    {name: "metered_count_uniq", agg_type: :unique_count_agg, recurring: false},
    {name: "metered_latest", agg_type: :latest_agg, recurring: false},
    {name: "metered_max", agg_type: :max_agg, recurring: false},
    {name: "metered_sum", agg_type: :sum_agg, recurring: false},
    {name: "metered_weighted_sum", agg_type: :weighted_sum_agg, recurring: false},
    {name: "recurring_sum", agg_type: :sum_agg, recurring: true},
    {name: "recurring_weighted_sum", agg_type: :weighted_sum_agg, recurring: true}
  ]
  metrics_params.map do |params|
    organization.billable_metrics.find_or_create_by!(name: params[:name],
      code: params[:name],
      recurring: params[:recurring],
      aggregation_type: params[:agg_type],
      field_name: "test",
      weighted_interval: "seconds")
  end
end

def build_plan_args(organization, all_metrics, i)
  charges_params = []
  charge_models = Charge::CHARGE_MODELS.dup
  charge_models.delete(:custom)
  rand(2..25).times do
    metric = all_metrics.sample
    if metric.latest_agg?
      charge_models.delete(:graduated_percentage)
      charge_models.delete(:percentage)
    end
    unless metric.sum_agg?
      charge_models.delete(:dynamic)
    end
    charge_model = charge_models.sample
    pay_in_advance = (metric.payable_in_advance? && charge_model != :volume) ? [true, false].sample : false
    charge_params = {
      billable_metric_id: metric.id,
      charge_model: charge_model,
      pay_in_advance: pay_in_advance,
      prorated: can_be_prorated?(charge_model, metric, pay_in_advance) ? [true, false].sample : false
    }
    charges_params << charge_params
  end

  {
    organization_id: organization.id,
    name: "Plan parent #{i + 1}",
    code: "plan_parent_#{i + 1}-#{SecureRandom.hex(5)}",
    pay_in_advance: [true, false].sample,
    amount_cents: Faker::Number.number(digits: 4),
    amount_currency: "USD",
    interval: %i[monthly yearly].sample,
    trial_period: [0, 10].sample,
    charges: charges_params
  }
end

def can_be_prorated?(charge_model, billable_metric, pay_in_advance)
  unless billable_metric.weighted_sum_agg?
    return true if billable_metric.recurring? && pay_in_advance && charge_model == :standard
    return true if billable_metric.recurring? && !pay_in_advance && (charge_model == :standard || charge_model == :volume || charge_model == :graduated)
  end

  false
end

def generate_children_plans(plan, all_metrics, delete_charge_parents)
  5.times do
    # change plan, do not change charges
    res = Plans::OverrideService.call(plan: plan, params: {name: "Plan '#{plan.code}' child"})
    pl = res.plan
    pl.charges.update_all(parent_id: nil) if delete_charge_parents # rubocop:disable Rails/SkipsModelValidations

    # change charges models and properties (randomly)
    res = Plans::OverrideService.call(plan: plan, params: {charges: override_charges_rand(plan, all_metrics)})
    pl = res.plan
    pl.charges.update_all(parent_id: nil) if delete_charge_parents # rubocop:disable Rails/SkipsModelValidations
  end
end

def override_charges_rand(plan, all_metrics)
  plan.charges.map do |charge|
    charge_model = charge.charge_model
    metric = nil
    loop do
      metric = all_metrics.sample
      if metric.latest_agg?
        next if charge_model == :graduated_percentage
        next if charge_model == :percentage
      end
      unless metric.sum_agg?
        next if charge_model == :dynamic
      end
      break
    end

    pay_in_advance = (metric.payable_in_advance? && charge_model != :volume) ? [true, false].sample : false
    puts "before charge_mode: " + charge.charge_model.to_s
    puts "after charge_mode: " + charge_model.to_s
    {
      id: charge.id,
      billable_metric_id: metric.id,
      charge_model: charge_model,
      pay_in_advance: pay_in_advance,
      prorated: can_be_prorated?(charge_model, metric, pay_in_advance) ? [true, false].sample : false,
      properties: new_properties_for(charge_model)
    }
  end
end

def new_properties_for(charge_model)
  case charge_model&.to_sym
  when :standard then default_standard_properties
  when :graduated then default_graduated_properties
  when :package then default_package_properties
  when :percentage then default_percentage_properties
  when :volume then default_volume_properties
  when :graduated_percentage then default_graduated_percentage_properties
  when :dynamic then default_dynamic_properties
  end
end

def default_standard_properties
  {amount: "10"}
end

def default_graduated_properties
  {
    "graduated_ranges" => [
      {
        from_value: 0,
        to_value: nil,
        per_unit_amount: "10",
        flat_amount: "5"
      }
    ]
  }
end

def default_package_properties
  {
    package_size: 1,
    amount: "5",
    free_units: 10
  }
end

def default_percentage_properties
  {rate: "20"}
end

def default_volume_properties
  {
    "volume_ranges" => [
      {
        from_value: 0,
        to_value: nil,
        per_unit_amount: "20",
        flat_amount: "10"
      }
    ]
  }
end

def default_graduated_percentage_properties
  {
    "graduated_percentage_ranges" => [
      {
        from_value: 0,
        to_value: nil,
        rate: "20",
        fixed_amount: "20",
        flat_amount: "20"
      }
    ]
  }
end

def default_dynamic_properties
  {}
end
