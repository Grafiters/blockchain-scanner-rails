require 'openssl'
require 'base64'
require 'json'

class EncryptionService
    def initialize(params)
      @payload = params[:payload]
    end
  
    def decrypt
        cipher = 'aes-256-cbc'

        # Decode base64 encrypted data
        encrypted_data = Base64.decode64(@payload)
      
        # Parse JSON object
        encryption_object = JSON.parse(encrypted_data)
      
        # Extract IV and value from encryption object
        base64_iv = encryption_object['iv']
        base64_value = encryption_object['value']
      
        # Decode base64 IV
        iv = Base64.decode64(base64_iv)
      
        # Decode base64 encryption key
        encryption_key_buffer = Base64.decode64(encryption_key)
      
        # Create decipher
        decipher = OpenSSL::Cipher.new(cipher)
        decipher.decrypt
        decipher.key = encryption_key_buffer
        decipher.iv = iv
      
        # Decrypt the data
        decrypted_data = decipher.update(Base64.decode64(base64_value)) + decipher.final
      
        return JSON.parse(decrypted_data, symbolize_names: true)
    end
  
    private
  
    def encryption_key
      ENV.fetch('ENCRYPTION_KEY')
    end
end