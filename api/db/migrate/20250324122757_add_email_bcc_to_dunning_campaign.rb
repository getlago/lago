# frozen_string_literal: true

class AddEmailBccToDunningCampaign < ActiveRecord::Migration[7.2]
  def change
    add_column :dunning_campaigns, :bcc_emails, :string, array: true, default: []
  end
end
