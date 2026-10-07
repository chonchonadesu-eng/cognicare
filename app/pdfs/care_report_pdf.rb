# frozen_string_literal: true

require 'prawn'
require 'prawn/table'

class CareReportPdf < Prawn::Document
  # マスターデータ（SYMPTOM_CATEGORIES）から動的に症状ラベルのハッシュを生成
  SYMPTOM_LABELS = SYMPTOM_CATEGORIES.flat_map { |cat| cat[:symptoms] }.to_h { |s| [s[:id], s[:ja]] }.freeze

  TYPE_NAMES = {
    'alz' => 'アルツハイマー型',
    'vas' => '脳血管性',
    'lewy' => 'レビー小体型',
    'ftd' => '前頭側頭型'
  }.freeze

  # 👇 DailyLogモデルの定数をそのまま使う
  MEAL_LABELS  = DailyLog::MEAL_LABELS
  SLEEP_LABELS = DailyLog::SLEEP_LABELS
  MOOD_LABELS  = DailyLog::MOOD_LABELS

  def initialize(care_subject, records, daily_logs, period_start, period_end)
    super(
      page_size: 'A4',
      margin: [40, 50, 40, 50],
      info: {
        Title: '認知症ケア記録レポート',
        Author: '認知症タイプチェッカー',
        Subject: "#{care_subject.nickname}さんのケア記録",
        Creator: 'CareChecker App'
      }
    )

    @care_subject  = care_subject
    @records       = records
    @daily_logs    = daily_logs
    @period_start  = period_start
    @period_end    = period_end

    # 日本語フォント設定
    font_families.update(
      'IPAex' => {
        normal: Rails.root.join('vendor/fonts/ipaexg.ttf').to_s
      }
    )
    font 'IPAex'

    build_pdf
  end

  private

  # ===== 全体の組み立てフロー =====
  def build_pdf
    header_section
    summary_section
    check_records_section
    symptom_details_section # ←日ごとの症状チェック詳細
    daily_log_section
    disclaimer_section
  end

  # ===== 日ごとの具体的な症状チェック詳細 =====
  def symptom_details_section
    section_title '日別 症状チェック詳細'

    if @records.empty?
      text 'この期間の記録はありません。', size: 10, color: '64748b'
      move_down 16
      return
    end

    @records.each do |r|
      next if r.checked_ids.blank? || r.checked_ids.reject(&:blank?).empty?

      # 日付と傾向の小見出し
      text "#{r.recorded_on.strftime('%Y年%m月%d日')} （傾向タイプ: #{r.top_type ? "#{TYPE_NAMES[r.top_type]}的傾向" : '判定なし'} / チェック数: #{r.total_checked}項目）",
           size: 10, style: :bold, color: '1e293b'
      move_down 4

      # 症状の箇条書き
      valid_ids = r.checked_ids.reject(&:blank?)
      symptom_texts = valid_ids.map { |id| "・ #{SYMPTOM_LABELS[id] || id}" }

      text symptom_texts.join("\n"), size: 9, color: '334155', leading: 3
      move_down 12
    end

    move_down 10
  end

  # ===== ヘッダー =====
  def header_section
    fill_color '1e293b'
    fill_rectangle [0, cursor], bounds.width + 100, 70
    fill_color 'ffffff'

    bounding_box([10, cursor - 10], width: bounds.width) do
      text '認知症ケア記録レポート', size: 20, style: :bold, color: 'ffffff'
      move_down 6
      text "#{@care_subject.nickname}さん / #{@period_start.strftime('%Y年%m月%d日')} 〜 #{@period_end.strftime('%Y年%m月%d日')}",
           size: 11, color: '94a3b8'
    end

    move_down 20
    fill_color '000000'

    fill_color 'fef3c7'
    fill_rounded_rectangle [0, cursor], bounds.width, 36, 6
    fill_color '92400e'
    bounding_box([10, cursor - 8], width: bounds.width - 20) do
      text '※ このレポートは医療診断ではありません。症状の傾向を記録したものです。診断は必ず医師にご相談ください。',
           size: 9
    end
    fill_color '000000'
    move_down 24
  end

  # ===== サマリー =====
  def summary_section
    section_title '記録サマリー'

    total_checks = @records.size
    avg_checked  = @records.average(:total_checked)&.round(1) || 0
    top_type     = @records.group(:top_type).count.max_by { |_, v| v }&.first

    data = [
      ['チェック回数', "#{total_checks} 回"],
      ['平均チェック項目数',   "#{avg_checked} 項目"],
      ['最も多いタイプ傾向',   top_type ? TYPE_NAMES[top_type] : 'データなし'],
      ['記録期間', "#{(@period_end - @period_start).to_i + 1} 日間"]
    ]

    table(data, width: bounds.width, cell_style: { font: 'IPAex', size: 10, padding: [6, 10] }) do
      column(0).style(background_color: 'f1f5f9', font_style: :bold, width: 180)
      column(1).style(background_color: 'ffffff')
      row(0).style(background_color: 'e2e8f0')
    end

    move_down 20
  end

  # ===== チェック記録一覧 =====
  def check_records_section
    section_title '症状チェック記録'

    if @records.empty?
      text 'この期間の記録はありません。', size: 10, color: '64748b'
      move_down 16
      return
    end

    header = %w[日付 チェック数 傾向タイプ Alz Vas Lewy FTD]
    rows   = @records.map do |r|
      scores = r.scores || {}
      [
        r.recorded_on.strftime('%m/%d'),
        "#{r.total_checked} 項目",
        r.top_type ? TYPE_NAMES[r.top_type] : '-',
        scores['alz'].to_i,
        scores['vas'].to_i,
        scores['lewy'].to_i,
        scores['ftd'].to_i
      ]
    end

    table([header] + rows, width: bounds.width,
                           cell_style: { font: 'IPAex', size: 9, padding: [5, 8] }) do
      row(0).style(background_color: '1e293b', text_color: 'ffffff', font_style: :bold)
      rows.each_with_index do |_, i|
        row(i + 1).style(background_color: i.even? ? 'f8fafc' : 'ffffff')
      end
      column(0).width = 55
      column(1).width = 65
      column(2).width = 110
    end

    move_down 20
  end

  # ===== デイリーログ =====
  def daily_log_section
    section_title '日々の記録（食事・睡眠・機嫌）'

    if @daily_logs.empty?
      text 'この期間のデイリー記録はありません。', size: 10, color: '64748b'
      move_down 16
      return
    end

    header = %w[日付 食事 睡眠 機嫌 メモ]
    rows   = @daily_logs.map do |log|
      [
        log.logged_on.strftime('%m/%d'),
        MEAL_LABELS[log.meal] || '-',
        SLEEP_LABELS[log.sleep] || '-',
        MOOD_LABELS[log.mood] || '-',
        log.memo.present? ? log.memo.truncate(30) : '-'
      ]
    end

    table([header] + rows, width: bounds.width,
                           cell_style: { font: 'IPAex', size: 9, padding: [5, 8] }) do
      row(0).style(background_color: '1e293b', text_color: 'ffffff', font_style: :bold)
      rows.each_with_index do |_, i|
        row(i + 1).style(background_color: i.even? ? 'f8fafc' : 'ffffff')
      end
      column(0).width = 50
      column(1).width = 55
      column(2).width = 55
      column(3).width = 55
    end

    move_down 20
  end

  # ===== 免責事項 =====
  def disclaimer_section
    start_new_page if cursor < 100

    stroke_horizontal_rule
    move_down 10

    text '【免責事項】', size: 9, style: :bold, color: '64748b'
    move_down 4
    text 'このレポートは「認知症タイプチェッカー」アプリで記録された症状チェックおよびデイリーログをまとめたものです。' \
         '医療診断ではなく、症状の傾向を記録・参照するための資料です。' \
         '正確な診断・治療方針の決定は、必ず医師・専門医にご相談ください。',
         size: 9, color: '64748b', leading: 3

    move_down 8
    text "出力日時：#{Time.now.strftime('%Y年%m月%d日 %H:%M')}",
         size: 8, color: '94a3b8', align: :right
  end

  # ===== セクションタイトル =====
  def section_title(title)
    fill_color '7c9eff'
    fill_rectangle [0, cursor], 4, 18
    fill_color '000000'

    bounding_box([10, cursor], width: bounds.width) do
      text title, size: 13, style: :bold, color: '1e293b'
    end
    move_down 14
  end
end
