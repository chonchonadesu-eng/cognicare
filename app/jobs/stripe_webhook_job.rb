# app/jobs/stripe_webhook_job.rb
class StripeWebhookJob < ApplicationJob
  queue_as :default

  def perform(event_hash)
    # ハッシュからStripeのEventオブジェクトを復元
    event = Stripe::Event.construct_from(event_hash)

    # ここで初めて安全に時間のかかるDB処理を実行する
    StripeSubscriptionService.handle_webhook(event)
  rescue StandardError => e
    Rails.logger.error "[StripeWebhookJob Error] Event ID: #{event_hash['id']} - #{e.message}"
    # ジョブであれば、失敗しても後から自動でリトライ（再実行）ができるため本番でも超安全！
    raise e
  end
end
