# frozen_string_literal: true

class CreateCognicareMvp < ActiveRecord::Migration[7.1]
  def change
    # 1. 記事
    create_table :articles do |t|
      t.timestamps
    end

    # 2. ユーザー (Devise + 確認メール対応)
    create_table :users do |t|
      t.string :email, null: false, default: ""
      t.string :encrypted_password, null: false, default: ""
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at

      # 確認メール用
      t.string   :confirmation_token
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string   :unconfirmed_email

      # Google/LINEログイン用
      t.string :provider
      t.string :uid

      t.timestamps
    end
    add_index :users, :email, unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, :confirmation_token, unique: true

    # 3. ケア対象者 (1ユーザーにつき1人)
    create_table :care_subjects do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :nickname
      t.integer :birth_year
      t.string :relationship
      t.timestamps
    end

    # 4. チェック記録
    create_table :check_records do |t|
      t.references :care_subject, null: false, foreign_key: true
      t.date :recorded_on
      t.timestamps
    end
    add_index :check_records, [:care_subject_id, :recorded_on]

    # 5. デイリーログ
    create_table :daily_logs do |t|
      t.references :care_subject, null: false, foreign_key: true
      t.date :logged_on, null: false
      
      t.integer :meal, default: 1, null: false       # 食事 (0, 1, 2)
      t.integer :sleep, default: 1, null: false      # 睡眠 (0, 1, 2)
      t.integer :mood, default: 2, null: false       # 機嫌 (0, 1, 2, 3)
      t.text    :memo                                # 日記・介護メモ (長文対応のためtextがおすすめ)

      t.timestamps
    end
    add_index :daily_logs, [:care_subject_id, :logged_on], unique: true
  end
end