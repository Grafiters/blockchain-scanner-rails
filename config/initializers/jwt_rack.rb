# encoding: UTF-8
# frozen_string_literal: true

# Require JWT initializer to configure JWT key & options.
require_relative 'jwt'
require 'jwt/rack'

on_error = lambda do |_error|
  message = _error
  body    = { errors: [message] }.to_json
  headers = { 'Content-Type' => 'application/json', 'Content-Length' => body.bytesize.to_s }

  [401, headers, [body]]
end

# TODO: Fixme in jwt-rack handle api/v2// as api/v2.
auth_args = {
  secret:   Rails.configuration.x.jwt_public_key,
  options:  Rails.configuration.x.jwt_options,
  verify:   Rails.configuration.x.jwt_public_key.present?,
  exclude:  %w(/api/v2/account /api/v2//config /api/v2/config /api/v2//config),
  on_error: on_error
}