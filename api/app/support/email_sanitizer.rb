# frozen_string_literal: true

module EmailSanitizer
  def self.call(email)
    return email if email.blank?

    email
      .gsub(Regex::DASH_LOOKALIKES_CHARS, "-")
      .gsub(Regex::INVISIBLE_CHARS, "")
      .strip
  end
end
