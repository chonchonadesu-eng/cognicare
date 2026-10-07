# frozen_string_literal: true

class CheckRecord < ApplicationRecord
  belongs_to :care_subject

  # データベースのテキストと、Rubyの配列/ハッシュを自動で変換してくれる設定
  serialize :checked_ids, coder: YAML
  serialize :scores, coder: YAML

  # バリデーション
  validates :recorded_on, presence: true
  # アプリ側でもエラーメッセージを出すために残しますが、必ずDB側にUNIQUEインデックスも貼ってください
  validates :recorded_on, uniqueness: { scope: :care_subject_id, message: 'この日の記録はすでに存在します' }

  validates :scores, presence: true

  # コールバック
  before_save :set_top_type

  private

  def set_top_type
    # scores がハッシュ形式でない、または空なら何もしない（クラッシュ防止）
    return unless scores.is_a?(Hash) && scores.present?

    max_score_pair = scores.max_by do |_, v|
      v.to_f # もし整数だけなら v.to_i でも可
    end

    # 最大値を持つキー（タイプ名）を代入
    self.top_type = max_score_pair&.first
  end
end
