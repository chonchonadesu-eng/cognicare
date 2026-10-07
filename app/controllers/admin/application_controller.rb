# frozen_string_literal: true

module Admin
  class ApplicationController < Administrate::ApplicationController
    before_action :authenticate_admin

    def authenticate_admin
      # 管理画面へのアクセスを一切禁止
      redirect_to root_path, alert: 'アクセス権限がありません。'
    end
  end
end
