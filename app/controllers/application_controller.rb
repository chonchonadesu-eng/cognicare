# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Deviseのコントローラが動くときだけ、パラメーターを許可
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  # ログイン直後のリダイレクト先
  def after_sign_in_path_for(_resource)
    root_path
  end

  # 新規登録が完了した直後の行き先
  def after_sign_up_path_for(_resource)
    new_care_subject_path
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :patient_name])
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :patient_name])
  end
end
