# frozen_string_literal: true

OmniAuth.config.allowed_request_methods = %i[post get]

# セキュリティチェックを一時的にバイパスする設定
OmniAuth.config.before_request_phase do |env|
  # トークンエラーを無視するためのフラグを立てる
  env['omniauth.strategy'].options[:verify_authenticity_token] = false if Rails.env.development?
end
