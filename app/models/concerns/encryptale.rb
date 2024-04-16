# encoding: UTF-8
# frozen_string_literal: true

module Encryptable
    extend ActiveSupport::Concern

    class_methods do
        def attr_encrypted(*attributes)
            attributes.each do |attribute|
                define_method("#{attribute}=".to_sym) do |value|
                    return if value.nil?
                    self.public_send(
                        "#{attribute}_encrypted=".to_sym,
                        EncryptionService.new(value).encrypt
                    )
                end
    
                define_method(attribute) do
                    value = self.public_send("#{attribute}_encrypted".to_sym)
                    if value.present?
                        decrypt = EncryptionService.new(value).decrypt
                        if decrypt.include?("{")
                            change = decrypt.gsub("=>", ":")
                            return JSON.parse(change)
                        else
                            return decrypt
                        end
                    else
                        return ""
                    end

                end
            end
        end
    end
end