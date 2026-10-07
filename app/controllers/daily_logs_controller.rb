# frozen_string_literal: true

class DailyLogsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_care_subject

  def create
    target_date = begin
      params[:logged_on].present? ? Date.parse(params[:logged_on].to_s) : Date.today
    rescue ArgumentError
      Date.today
    end

    @daily_log = @care_subject.daily_logs.find_or_initialize_by(logged_on: target_date)

    allowed_params = respond_to?(:direct_daily_log_params, true) ? direct_daily_log_params : daily_log_params

    permitted_data = allowed_params.to_h
    permitted_data[:meal]  = permitted_data[:meal].to_i  if permitted_data[:meal].present?
    permitted_data[:sleep] = permitted_data[:sleep].to_i if permitted_data[:sleep].present?
    permitted_data[:mood]  = permitted_data[:mood].to_i  if permitted_data[:mood].present?

    @daily_log.assign_attributes(permitted_data)

    respond_to do |format|
      if @daily_log.save
        flash[:notice] = '生活記録を保存しました'
        # ▼ 成功時は一覧画面（check_records）へアンカー付きでリダイレクト
        format.html { redirect_to care_subject_check_records_path(@care_subject, anchor_date: target_date), status: :see_other }
      else
        Rails.logger.error "[DailyLog Error] 保存に失敗しました: #{@daily_log.errors.full_messages}"
        flash[:alert] = "記録の保存に失敗しました: #{@daily_log.errors.full_messages.join(', ')}"

        # ▼ 【重要】失敗時も存在しない daily_logs に行かせず、必ず check_records_path へ戻す！
        format.html { redirect_to care_subject_check_records_path(@care_subject, anchor_date: target_date), status: :unprocessable_entity }
      end
    end
  end

  private

  def set_care_subject
    @care_subject = current_user.care_subjects.find(params[:care_subject_id])
  end

  def direct_daily_log_params
    params.permit(:meal, :sleep, :mood, :memo, :logged_on)
  end

  def daily_log_params
    # パラメータとしても meal, sleep, mood がそのまま数字（整数）として入ってくることを許可します
    params.permit(:logged_on, :meal, :sleep, :mood, :memo)
  end
end
