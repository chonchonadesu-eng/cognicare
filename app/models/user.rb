# frozen_string_literal: true

class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable,
         :omniauthable, omniauth_providers: %i[google_oauth2 line]

  # 今後のことを考え複数形
  has_many :care_subjects, dependent: :destroy

  # 自分が登録したケア対象者を取得するヘルパーメソッド（必要であれば複数形や最初の1件に合わせる）
  def accessible_care_subject
    care_subjects.first
  end
end
