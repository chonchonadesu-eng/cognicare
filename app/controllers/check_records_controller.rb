# frozen_string_literal: true

class CheckRecordsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_care_subject

  def index
    @check_records_json = @check_records.to_json if defined?(@check_records)


    if params[:anchor_date].present?
      parsed_date = Date.parse(params[:anchor_date]) rescue Date.today

      # 未来の日付が指定された場合「今日」に強制補正（セキュリティガード）
      parsed_date = Date.today if parsed_date > Date.today

      # 31日前に制限（セキュリティガード）
      min_date = 31.days.ago.to_date
      parsed_date = min_date if parsed_date < min_date

      @current_anchor = parsed_date
    else
      # ページを開いた最初は必ず「今日」が一番上にくる
      @current_anchor = Date.today
    end

    # 選択された基準日に応じた1週間分のデータを取得
    calendar_data = build_calendar_data(@current_anchor)
    @records_by_date    = calendar_data[:records_by_date]
    @daily_logs_by_date = calendar_data[:daily_logs_by_date]

    # マスタハッシュ定義
    @symptom_labels = {
      'm1' => '同じことを何度も繰り返し話す・聞く',
      'm2' => '体験したこと自体をまるごと忘れる',
      'm3' => '今日の日付・曜日・年がわからなくなった',
      'm4' => '自分がどこにいるかわからなくなる',
      'm5' => '昔のことはよく覚えているが、最近のことを忘れやすい',
      'm6' => '物の名前が出てこなくなった（言葉が出にくい）',
      'b1' => '同じ行動を毎日決まったルーティンで繰り返す',
      'b2' => '目的もなくうろうろ歩き回る（徘徊）',
      'b3' => '火の消し忘れや水の出しっぱなしなど、日常的なミスが増えた',
      'b4' => '財布・鍵などをどこに置いたかわからなくなる頻度が増えた',
      'b5' => '料理・家事など、以前できていたことができなくなった',
      'b6' => '食べ物でないものを口に入れる、または過食になった',
      'e1' => '以前と比べて無気力・無関心になった（アパシー）',
      'e2' => '突然怒り出す・感情のコントロールが難しくなった',
      'e3' => '以前は温和だったのに、粗暴な言動が見られるようになった',
      'e4' => 'うつ状態・気分の落ち込みが目立つ',
      'e5' => '「盗まれた」などの疑い・妄想がある',
      'e6' => '自分が認知症であることを強く否定する',
      'p1' => '実際にはいない人・動物などが見える（幻視）',
      'p2' => '睡眠中に大声を出したり、手足を激しく動かしたりする',
      'p3' => '体が硬い・動きがゆっくりになった（パーキンソン症状）',
      'p4' => '症状の波がある（良い日と悪い日の差が大きい）',
      'p5' => '突然倒れた・麻痺が出た経験がある（脳卒中の既往）',
      'p6' => '歩行がおぼつかない・小刻みな歩き方になった',
      's1' => '会話の内容がかみ合わなくなった',
      's2' => 'TPOをわきまえない言動が増えた',
      's3' => '趣味や人付き合いへの興味がなくなった',
      's4' => 'お金の管理ができなくなった（計算・支払いが難しい）',
      's5' => '薬の管理ができなくなった',
      's6' => '電話やスマホの操作が難しくなった'
    }.with_indifferent_access
  end

  def create
    target_date = params[:recorded_on].present? ? Date.parse(params[:recorded_on]) : Date.today

    # 症状チェック（CheckRecord）の保存・更新
    @record = @care_subject.check_records.find_or_initialize_by(recorded_on: target_date)
    checked_ids = Array(params[:checked_ids]).reject(&:blank?)

    scores = calculate_scores(checked_ids)
    top_type = scores.max_by { |_, v| v }&.first

    @record.assign_attributes(
      checked_ids: checked_ids,
      total_checked: checked_ids.size,
      scores: scores,
      top_type: top_type,
      lang: params[:lang] || 'ja'
    )

    if @record.save
      redirect_to care_subject_check_records_path(@care_subject), notice: '行動チェックを保存しました', status: :see_other
    else
      redirect_to care_subject_check_records_path(@care_subject), alert: '保存に失敗しました', status: :see_other
    end
  end

  def show
    @record = @care_subject.check_records.find(params[:id])
  end

  private

  def build_calendar_data(anchor_date)
    # anchor_date から計7日間の範囲を計算
    start_range = anchor_date - 6.days
    end_range   = anchor_date

    {
      records_by_date: @care_subject.check_records
                                     .where(recorded_on: start_range..end_range)
                                     .order(recorded_on: :asc)
                                     .index_by { |r| r.recorded_on.to_s },

      daily_logs_by_date: @care_subject.daily_logs
                                       .where(logged_on: start_range..end_range)
                                       .order(logged_on: :asc)
                                       .each_with_object({}) { |log, hash|
                                         hash[log.logged_on.to_s] = {
                                           meal: log.meal_before_type_cast,
                                           sleep: log.sleep_before_type_cast,
                                           mood: log.mood_before_type_cast,
                                           memo: log.memo
                                         }
                                       }
    }
  end

  def set_care_subject
    subject_id = params[:care_subject_id] || current_user.care_subjects.first&.id
    if subject_id.nil?
      redirect_to care_subjects_path and return
    end

    @care_subject = current_user.care_subjects.find(subject_id)
  rescue ActiveRecord::RecordNotFound
    redirect_to care_subjects_path, alert: '記録が見つかりません' and return
  end

  def build_graph_data
    records = @care_subject.check_records.order(recorded_on: :desc).limit(90).reverse

    labels = []
    total  = []
    alz    = []
    vas    = []
    lewy   = []
    ftd    = []

    records.each do |r|
      labels << r.recorded_on.strftime('%m/%d')
      total  << r.total_checked
      alz    << (r.scores&.dig('alz') || 0)
      vas    << (r.scores&.dig('vas') || 0)
      lewy   << (r.scores&.dig('lewy') || 0)
      ftd    << (r.scores&.dig('ftd') || 0)
    end

    { labels: labels, total: total, alz: alz, vas: vas, lewy: lewy, ftd: ftd }
  end

  def calculate_scores(checked_ids)
    scores = { 'alz' => 0, 'vas' => 0, 'lewy' => 0, 'ftd' => 0 }
    SYMPTOM_WEIGHTS.each do |sym_id, weights|
      next unless checked_ids.include?(sym_id)

      weights.each { |type, w| scores[type] += w }
    end
    scores
  end

  def generate_ai_advice(checked_ids)
    if checked_ids.size > 5
      '今日は少し変化が多いようです。夜は静かな環境を整えて、あなたもゆっくり休めてくださいね。'
    elsif checked_ids.any? { |id| id.start_with?('p') }
      '歩行や動作に少し注意が必要かもしれません。足元を明るくして、転倒に気をつけて見守りましょう。'
    else
      '穏やかな一日ですね。この調子で、お互いのペースを大切に過ごしていきましょう。'
    end
  end

  SYMPTOM_WEIGHTS = {
    'm1' => { 'alz' => 3, 'vas' => 1, 'lewy' => 1, 'ftd' => 1 },
    'm2' => { 'alz' => 3, 'vas' => 2, 'lewy' => 2, 'ftd' => 1 },
    'm3' => { 'alz' => 3, 'vas' => 2, 'lewy' => 1, 'ftd' => 1 },
    'm4' => { 'alz' => 3, 'vas' => 2, 'lewy' => 2, 'ftd' => 1 },
    'm5' => { 'alz' => 2, 'vas' => 2, 'lewy' => 1, 'ftd' => 3 },
    'b1' => { 'alz' => 1, 'vas' => 1, 'lewy' => 1, 'ftd' => 3 },
    'b2' => { 'alz' => 3, 'vas' => 2, 'lewy' => 1, 'ftd' => 2 },
    'b3' => { 'alz' => 3, 'vas' => 2, 'lewy' => 2, 'ftd' => 2 },
    'b4' => { 'alz' => 3, 'vas' => 1, 'lewy' => 1, 'ftd' => 1 },
    'b5' => { 'alz' => 3, 'vas' => 2, 'lewy' => 2, 'ftd' => 2 },
    'b6' => { 'alz' => 1, 'vas' => 1, 'lewy' => 1, 'ftd' => 3 },
    'e1' => { 'alz' => 2, 'vas' => 2, 'lewy' => 2, 'ftd' => 3 },
    'e2' => { 'alz' => 2, 'vas' => 3, 'lewy' => 2, 'ftd' => 3 },
    'e3' => { 'alz' => 1, 'vas' => 2, 'lewy' => 1, 'ftd' => 3 },
    'e4' => { 'alz' => 2, 'vas' => 3, 'lewy' => 3, 'ftd' => 2 },
    'e5' => { 'alz' => 3, 'vas' => 2, 'lewy' => 2, 'ftd' => 1 },
    'e6' => { 'alz' => 3, 'vas' => 2, 'lewy' => 1, 'ftd' => 2 },
    'p1' => { 'alz' => 1, 'vas' => 1, 'lewy' => 3, 'ftd' => 1 },
    'p2' => { 'alz' => 0, 'vas' => 0, 'lewy' => 3, 'ftd' => 0 },
    'p3' => { 'alz' => 0, 'vas' => 1, 'lewy' => 3, 'ftd' => 1 },
    'p4' => { 'alz' => 1, 'vas' => 2, 'lewy' => 3, 'ftd' => 1 },
    'p5' => { 'alz' => 0, 'vas' => 3, 'lewy' => 0, 'ftd' => 0 },
    'p6' => { 'alz' => 1, 'vas' => 3, 'lewy' => 2, 'ftd' => 1 },
    's1' => { 'alz' => 2, 'vas' => 2, 'lewy' => 1, 'ftd' => 3 },
    's2' => { 'alz' => 1, 'vas' => 1, 'lewy' => 1, 'ftd' => 3 },
    's3' => { 'alz' => 2, 'vas' => 2, 'lewy' => 2, 'ftd' => 3 },
    's4' => { 'alz' => 3, 'vas' => 2, 'lewy' => 2, 'ftd' => 2 },
    's5' => { 'alz' => 3, 'vas' => 2, 'lewy' => 2, 'ftd' => 1 },
    's6' => { 'alz' => 2, 'vas' => 2, 'lewy' => 2, 'ftd' => 1 }
  }.freeze
end
