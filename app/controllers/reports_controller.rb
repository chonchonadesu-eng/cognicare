# frozen_string_literal: true

class ReportsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_care_subject

  # GET /care_subjects/:care_subject_id/report.pdf
  def show
    @period_start = params[:from] ? Date.parse(params[:from]) : 1.month.ago.to_date
    @period_end   = params[:to]   ? Date.parse(params[:to])   : Date.today

    @records      = @care_subject.check_records
                                 .where(recorded_on: @period_start..@period_end)
                                 .order(:recorded_on)

    @daily_logs   = @care_subject.daily_logs
                                 .where(logged_on: @period_start..@period_end)
                                 .order(:logged_on)

    respond_to do |format|
      format.pdf do
        pdf      = CareReportPdf.new(@care_subject, @records, @daily_logs, @period_start, @period_end)
        filename = "care_report_#{@care_subject.nickname}_#{Date.today}.pdf"
        send_data pdf.render,
                  filename: filename,
                  type: 'application/pdf',
                  disposition: 'attachment'
      end
    end
  end

  private

  def set_care_subject
    @care_subject = current_user.care_subjects.find(params[:care_subject_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: '記録が見つかりません'
  end
end