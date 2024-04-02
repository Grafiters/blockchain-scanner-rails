# # frozen_string_literal: true

require 'carrierwave/storage/abstract'
require 'carrierwave'
require 'carrierwave/storage/file'
require 'carrierwave/storage/fog'

CarrierWave.configure do |config|
  config.fog_credentials = {
    provider: 'AWS',
    aws_signature_version: ENV.fetch("AWS_SIGNATUR_VERSION", 4),
    aws_access_key_id: ENV.fetch("AWS_ACCESS_KEY_ID",""),
    aws_secret_access_key: ENV.fetch("AWS_SECRET_ACCESS_KEY",""),
    region: ENV.fetch("AWS_REGION", "es-west-1"),
    endpoint: ENV.fetch("AWS_ENDPOINT", "http://192.168.1.64:9000"),
    path_style: ENV.fetch("AWS_PATH_SYLE", true)
  }
  config.fog_directory = ENV.fetch("BUCKET_NAME", "backendexchange")
end