# frozen_string_literal: true

class CareSubject < ApplicationRecord
  belongs_to :user_profile, optional: true # 🌟 前回のレビュー通り、NULLを許容するためoptionalを指定
  belongs_to :user

  has_many :check_records, dependent: :destroy
  has_many :daily_logs,    dependent: :destroy

  validates :nickname, presence: true

  # 🌟 改善：直近30日のチェック記録（無駄な.to_dateを減らしスッキリ記述）
  def recent_records(days = 30)
    check_records.where(recorded_on: days.days.ago.to_date..)
                 .order(recorded_on: :asc)
  end

  # 🌟 改善：1回のクエリで14日前までのデータを一気に取得し、メモリ上で計算する（N+1撲滅）
  def symptom_increasing?
    today = Date.current

    # 1. 14日前から今日までのレコードを1回のSQLでまとめて取得（高速化）
    records_14_days = check_records.where(recorded_on: (today - 13.days)..today)

    # 2. メモリ上で「直近7日」と「その前の7日」に分配する（DBに2回問い合わせない！）
    recent_group, before_group = records_14_days.partition { |r| r.recorded_on >= today - 6.days }

    # 3. それぞれの平均値を算出
    recent_avg = recent_group.any? ? recent_group.sum(&:total_checked).to_f / recent_group.size : 0.0
    before_avg = before_group.any? ? before_group.sum(&:total_checked).to_f / before_group.size : 0.0

    # 4. 業務ロジックのバグ修正
    # 前の期間が0かつ、今の期間に症状が出ている場合は「増加」とみなしてアラートを出す
    return true if before_avg.zero? && recent_avg.positive?
    return false if before_avg.zero? && recent_avg.zero?

    # 20%以上増加でアラート
    recent_avg > before_avg * 1.2
  end
end
