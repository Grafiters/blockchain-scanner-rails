require 'openssl'
require 'base64'
require 'json'

class EncryptionService
    def initialize(params)
      @payload = params
      @encryptor = ActiveSupport::MessageEncryptor.new(encryption_key)
    end
  
    def encrypt
      @encryptor.encrypt_and_sign(@payload.to_s)
    end

    def decrypt
      @encryptor.decrypt_and_verify(@payload)
    end
  
    private
  
    def encryption_key
      key = ENV.fetch('ENCRYPTION_KEY')
      return Base64.decode64(key)
    end
end