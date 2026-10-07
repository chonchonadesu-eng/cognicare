# frozen_string_literal: true

class DailyLog < ApplicationRecord
  belongs_to :care_subject

  attribute :meal, :integer
  attribute :sleep, :integer
  attribute :mood, :integer
  attribute :memo, :string

  validates :logged_on, presence: true
  validates :logged_on, uniqueness: { scope: :care_subject_id }

  # enumの定義
  enum :meal,  { bad: 0, normal: 1, good: 2 }, prefix: :meal
  enum :sleep, { bad: 0, normal: 1, good: 2 }, prefix: :sleep
  enum :mood,  { bad: 0, normal: 1, good: 2, excited: 3 }, prefix: :mood

  # 👇 キーを「整数」だけに絞ってシンプルに！
  MEAL_LABELS = {
    2 => '🍽️ しっかり（完食〜８割）',
    1 => '🍴 半分くらい（５割前後）',
    0 => '🥣 少量（２割以下）'
  }.freeze

  SLEEP_LABELS = {
    2 => '💤 良眠',
    1 => '💤 浅眠',
    0 => '💧 不眠'
  }.freeze

  MOOD_LABELS = {
    3 => '😊 良い',
    2 => '😐 普通',
    1 => '🙁 悪い',
    0 => '😡 興奮'
  }.freeze
end
