# frozen_string_literal: true

class HomeController < ApplicationController
  before_action :authenticate_user!

  def index
    @care_subject = current_user.care_subjects.first

    return unless @care_subject

    # 1. 今月の記録回数
    @monthly_count = @care_subject.check_records.where(recorded_on: Time.current.all_month).count

    # 2. 症状チェックグラフデータの作成
    @graph_data = build_symptom_graph_data(@care_subject)

    # 3. カレンダー用の生活記録（食事・睡眠・機嫌・メモなど）
    @daily_logs = @care_subject.daily_logs
                               .where(logged_on: Time.current.all_month)
                               .index_by(&:logged_on)
  end

  private

  def build_symptom_graph_data(care_subject)
    records = care_subject.check_records.order(recorded_on: :asc).last(30)
    {
      labels: records.map { |r| r.recorded_on.strftime('%m/%d') },
      total: records.map(&:total_checked),
      alz: records.map { |r| r.scores&.dig('alz') || 0 },
      vas: records.map { |r| r.scores&.dig('vas') || 0 },
      lewy: records.map { |r| r.scores&.dig('lewy') || 0 },
      ftd: records.map { |r| r.scores&.dig('ftd') || 0 }
    }
  end
end
