# frozen_string_literal: true

KEY_DIR = Rails.root.join("config/keys")
PRIVATE_KEY_PATH = KEY_DIR.join("private.pem")

private_key_string =
  if File.exist?(PRIVATE_KEY_PATH)
    File.read(PRIVATE_KEY_PATH)
  else
    Base64.decode64(ENV["LAGO_RSA_PRIVATE_KEY"])
  end

if private_key_string.blank?
  abort("Error: Private key is blank, you must provide a private key to start the application. Exiting...") # rubocop:disable Rails/Exit
end

RsaPrivateKey = OpenSSL::PKey::RSA.new(private_key_string)
RsaPublicKey = RsaPrivateKey.public_key
