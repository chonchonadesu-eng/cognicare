# frozen_string_literal: true

# app/controllers/logouts_controller.rb
class LogoutsController < ApplicationController
  def show
    # 1. 手動管理のセッションをクリア
    session[:user_id] = nil

    # 2. 🌟 Deviseのログイン状態も安全にサインアウト（ログアウト）させる
    sign_out(current_user) if respond_to?(:sign_out) && user_signed_in?

    # 3. 🌟 誰でも文句なしに入れる「Devise公式のログイン画面」へ直接戻す！
    redirect_to new_user_session_path, notice: 'ログアウトしました。'
  end
end
