# frozen_string_literal: true

Rails.application.routes.draw do
  # ▼ 開発環境（development）のときだけ letter_opener_web のルートを有効にする
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  devise_for :users, controllers: {
    omniauth_callbacks: 'users/omniauth_callbacks'
  }

  get 'static_pages/privacy'
  get 'articles/index'

  get '/logout', to: 'logouts#show'

  # 1. 管理画面の設定（adminグループ）
  namespace :admin do
    resources :articles
    root to: 'articles#index'
  end

  # 2. ユーザー用のコラムページ設定
  resources :articles, only: %i[index show]

  # 3. 診断機能（dementia_checker）の設定
  resources :dementia_checker, only: [] do
    collection do
      get  :index      # チェッカーページ
      post :analyze    # AI分析リクエスト
    end
  end

  # 4. その他の設定
  get 'home/index'
  get 'up' => 'rails/health#show', as: :rails_health_check

  # アプリ全体のトップページ
  root 'check_records#index'

  get 'privacy_policy', to: 'static_pages#privacy'

  # 5. 被介護者（care_subjects）とそれに紐づく機能
  resources :care_subjects do
    # 診断記録
    resources :check_records do
      collection do
        get :report # 印刷用レポート画面のURL
      end
    end

    # 日常ログ
    resources :daily_logs, only: %i[create new]
  end

  # PDF出力
  resource :report, only: [:show]
end
