# frozen_string_literal: true

class CareSubjectsController < ApplicationController
  before_action :authenticate_user!

  def index
    @care_subjects = current_user.care_subjects

    # 🌟 1人目の対象者を取得
    first_subject = @care_subjects.first

    if first_subject.present?
      # ⭕ 1人でも登録があれば、その人のカレンダー（記録一覧）へ移動（これはループしないので安全！）
      redirect_to care_subject_check_records_path(first_subject) and return
    else
      @care_subject = current_user.care_subjects.build
      render :new and return
    end
  end

  def new
    # newアクションは「自分がオーナーになる対象者」を作るため、既存の記述で安全です
    @care_subject = current_user.care_subjects.build
  end

  def create
    @care_subject = current_user.care_subjects.build(care_subject_params)
    # 🌟 改善：ビューの hidden_field を汚さず、バックエンドで安全に初期値を保証する
    @care_subject.birth_year ||= 0
    @care_subject.relationship ||= '未設定'

    if @care_subject.save
      redirect_to care_subject_check_records_path(@care_subject),
                  notice: "#{@care_subject.nickname}の記録を開始します"
    else
      logger.error "CareSubject作成失敗: #{@care_subject.errors.full_messages.join(', ')}"
      flash.now[:alert] = '入力内容に不備があります。確認のうえ再度お試しください。'
      render :new, status: :unprocessable_entity
    end
  end

  private

  def care_subject_params
    params.require(:care_subject).permit(:nickname, :birth_year, :relationship)
  end
end
