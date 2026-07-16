# frozen_string_literal: true

class DataExportMailer < ApplicationMailer
  def completed
    @data_export = params[:data_export]
    @resource_type = @data_export.resource_type.humanize.downcase
    user = @data_export.user

    return if @data_export.expired?
    return unless @data_export.completed?

    I18n.with_locale(:en) do
      mail(
        to: user.email,
        from: ENV["LAGO_FROM_EMAIL"],
        subject: I18n.t(
          "email.data_export.completed.subject",
          resource_type: @resource_type
        )
      )
    end
  end
end
