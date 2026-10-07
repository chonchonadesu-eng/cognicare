# frozen_string_literal: true

class DementiaCheckerController < ApplicationController
  def index
    @symptom_categories = SYMPTOM_CATEGORIES
    @dementia_types     = DEMENTIA_TYPES
    @symptom_labels     = build_symptom_labels_hash

    return unless user_signed_in?

    @care_subject = fetch_current_care_subject
    @record       = fetch_weekly_latest_record if @care_subject
  end

  def create
    @care_subject = current_user.care_subjects.find(params[:care_subject_id])
    @record = @care_subject.check_records.build(dementia_checker_params)

    if @record.save
      redirect_to dementia_checker_index_path(care_subject_id: @care_subject.id),
                  notice: 'チェック結果を保存しました。'
    else
      render_index_with_errors
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: '不正なアクセスです。'
  end

  def analyze
    checked_ids    = params[:checked_ids] || []
    scores         = calculate_scores(checked_ids)
    sorted_results = sort_results(scores)

    save_record_if_needed!(checked_ids, scores, sorted_results.first)
    render_success_response(sorted_results)
  rescue StandardError => e
    handle_analyze_exception(e)
  end

  private

  # 🧠 1. indexアクション用のデータ取得 関連

  # SYMPTOM_CATEGORIES の中から ID と 日本語(ja) のペアを抜き出してハッシュ化する
  def build_symptom_labels_hash
    labels = {}
    SYMPTOM_CATEGORIES.each do |cat|
      cat[:symptoms].each { |sym| labels[sym[:id]] = sym[:ja] }
    end
    labels
  end

  # 対象者がいる場合はその人を安全につかまえ、いない場合でもエラーを吐かずに nil を返す
  def fetch_current_care_subject
    if params[:care_subject_id].present?
      current_user.care_subjects.find_by(id: params[:care_subject_id])
    else
      current_user.care_subjects.first
    end
  end

  # ログインのみのユーザーの仕様（直近1週間）に合わせて最新の1件を取得する
  def fetch_weekly_latest_record
    start_date = 6.days.ago.to_date
    end_date   = Time.zone.today

    @care_subject.check_records
                 .where(recorded_on: start_date..end_date)
                 .order(created_at: :desc)
                 .first
  end

  # 💾 2. 保存・データ組み立て 関連

  # 必要に応じてレコードを保存する（ログインしていない人を弾くためのガード）
  def save_record_if_needed!(checked_ids, scores, top_result)
    return unless user_signed_in? && params[:care_subject_id].present?

    care_subject = current_user.care_subjects.find(params[:care_subject_id])
    record = care_subject.check_records.find_or_initialize_by(recorded_on: Time.zone.today)
    record.update!(build_record_attributes(checked_ids, scores, top_result))
  end

  def build_record_attributes(checked_ids, scores, top_result)
    {
      checked_ids: checked_ids,
      scores: scores,
      top_type: top_result[:key].to_s,
      total_checked: checked_ids.size,
      ai_advice: nil,
      lang: params[:lang] || 'ja'
    }
  end

  # 📢 3. レスポンス・エラーハンドリング 関連

  def render_success_response(sorted_results)
    render json: {
      results: sorted_results,
      ai_advice: nil,
      lang: params[:lang] || 'ja'
    }
  end

  # 例外処理を一手に担当して安全にエラーを返す
  def handle_analyze_exception(exception)
    case exception
    when ActiveRecord::RecordNotFound
      render json: { error: '不正なアクセスです。' }, status: :not_found
    else
      logger.error "DementiaChecker Error: #{exception.message}"
      render json: { error: 'システムエラーが発生しました。' }, status: :unprocessable_entity
    end
  end

  # ---------- スコア計算 ----------
  def calculate_scores(checked_ids)
    scores = { alz: 0, vas: 0, lewy: 0, ftd: 0 }
    SYMPTOM_CATEGORIES.each do |cat|
      cat[:symptoms].each do |sym|
        next unless checked_ids.include?(sym[:id])

        sym[:weights].each { |type, w| scores[type] += w }
      end
    end
    scores
  end

  def sort_results(scores)
    total = scores.values.sum.to_f
    scores.sort_by { |_, v| -v }.map do |key, val|
      pct = total.positive? ? (val / total * 100).round : 0
      DEMENTIA_TYPES[key].merge(key: key, score: val, pct: pct)
    end
  end

  # ---------- マスターデータ ----------
  SYMPTOM_CATEGORIES = [
    {
      id: 'memory',
      label: '記憶・見当識',
      icon: '🧠',
      color: '#7C9EFF',
      symptoms: [
        { id: 'm1', ja: '同じことを何度も繰り返し話す・聞く', weights: { alz: 3, vas: 1, lewy: 1, ftd: 1 } },
        { id: 'm2', ja: '体験したこと自体をまるごと忘れる', weights: { alz: 3, vas: 2, lewy: 2, ftd: 1 } },
        { id: 'm3', ja: '今日の日付・曜日・年がわからなくなった', weights: { alz: 3, vas: 2, lewy: 1, ftd: 1 } },
        { id: 'm4', ja: '自分がどこにいるかわからなくなる', weights: { alz: 3, vas: 2, lewy: 2, ftd: 1 } },
        { id: 'm5', ja: '昔のことはよく覚えているが、最近のことを忘れやすい', weights: { alz: 3, vas: 1, lewy: 1, ftd: 1 } },
        { id: 'm6', ja: '物の名前が出てこなくなった（言葉が出にくい）', weights: { alz: 2, vas: 2, lewy: 1, ftd: 3 } }
      ]
    },
    {
      id: 'behavior',
      label: '行動・生活',
      icon: '🚶',
      color: '#A78BFA',
      symptoms: [
        { id: 'b1', ja: '同じ行動を毎日決まったルーティンで繰り返す', weights: { alz: 1, vas: 1, lewy: 1, ftd: 3 } },
        { id: 'b2', ja: '目的もなくうろうろ歩き回る（徘徊）', weights: { alz: 3, vas: 2, lewy: 1, ftd: 2 } },
        { id: 'b3', ja: '火の消し忘れや水の出しっぱなしなど、日常的なミスが増えた', weights: { alz: 3, vas: 2, lewy: 2, ftd: 2 } },
        { id: 'b4', ja: '財布・鍵などをどこに置いたかわからなくなる頻度が増えた', weights: { alz: 3, vas: 1, lewy: 1, ftd: 1 } },
        { id: 'b5', ja: '料理・家事など、以前できていたことができなくなった', weights: { alz: 3, vas: 2, lewy: 2, ftd: 2 } },
        { id: 'b6', ja: '食べ物でないものを口に入れる、または過食になった', weights: { alz: 1, vas: 1, lewy: 1, ftd: 3 } }
      ]
    },
    {
      id: 'emotion',
      label: '感情・性格',
      icon: '💭',
      color: '#34D399',
      symptoms: [
        { id: 'e1', ja: '以前と比べて無気力・無関心になった（アパシー）', weights: { alz: 2, vas: 2, lewy: 2, ftd: 3 } },
        { id: 'e2', ja: '突然怒り出す・感情のコントロールが難しくなった', weights: { alz: 2, vas: 3, lewy: 2, ftd: 3 } },
        { id: 'e3', ja: '以前は温和だったのに、粗暴な言動が見られるようになった', weights: { alz: 1, vas: 2, lewy: 1, ftd: 3 } },
        { id: 'e4', ja: 'うつ状態・気分の落ち込みが目立つ', weights: { alz: 2, vas: 3, lewy: 3, ftd: 2 } },
        { id: 'e5', ja: '「盗まれた」などの疑い・妄想がある', weights: { alz: 3, vas: 2, lewy: 2, ftd: 1 } },
        { id: 'e6', ja: '自分が認知症であることを強く否定する', weights: { alz: 3, vas: 2, lewy: 1, ftd: 2 } }
      ]
    },
    {
      id: 'physical',
      label: '身体・感覚',
      icon: '👁️',
      color: '#FBBF24',
      symptoms: [
        { id: 'p1', ja: '実際にはいない人・動物などが見える（幻視）', weights: { alz: 1, vas: 1, lewy: 3, ftd: 1 } },
        { id: 'p2', ja: '睡眠中に大声を出したり、手足を激しく動かしたりする', weights: { alz: 0, vas: 0, lewy: 3, ftd: 0 } },
        { id: 'p3', ja: '体が硬い・動きがゆっくりになった（パーキンソン症状）', weights: { alz: 0, vas: 1, lewy: 3, ftd: 1 } },
        { id: 'p4', ja: '症状の波がある（良い日と悪い日の差が大きい）', weights: { alz: 1, vas: 2, lewy: 3, ftd: 1 } },
        { id: 'p5', ja: '突然倒れた・麻痺が出た経験がある（脳卒中の既往）', weights: { alz: 0, vas: 3, lewy: 0, ftd: 0 } },
        { id: 'p6', ja: '歩行がおぼつかない・小刻みな歩き方になった', weights: { alz: 1, vas: 3, lewy: 2, ftd: 1 } }
      ]
    },
    {
      id: 'social',
      label: '社会・コミュニケーション',
      icon: '🗣️',
      color: '#F87171',
      symptoms: [
        { id: 's1', ja: '会話の内容がかみ合わなくなった', weights: { alz: 2, vas: 2, lewy: 1, ftd: 3 } },
        { id: 's2', ja: 'TPOをわきまえない言動が増えた', weights: { alz: 1, vas: 1, lewy: 1, ftd: 3 } },
        { id: 's3', ja: '趣味や人付き合いへの興味がなくなった', weights: { alz: 2, vas: 2, lewy: 2, ftd: 3 } },
        { id: 's4', ja: 'お金の管理ができなくなった（計算・支払いが難しい）', weights: { alz: 3, vas: 2, lewy: 2, ftd: 2 } },
        { id: 's5', ja: '薬の管理ができなくなった', weights: { alz: 3, vas: 2, lewy: 2, ftd: 1 } },
        { id: 's6', ja: '電話やスマホの操作が難しくなった', weights: { alz: 2, vas: 2, lewy: 2, ftd: 1 } }
      ]
    }
  ].freeze

  DEMENTIA_TYPES = {
    alz: {
      name: 'アルツハイマー型認知症',
      short: 'アルツハイマー型',
      color: '#7C9EFF',
      icon: '🔵',
      prevalence: '最多 約60〜70%',
      description: '認知症の中で最も多く、脳にアミロイドβが蓄積することで発症します。記憶障害から始まり、ゆっくりと進行するのが特徴です。',
      care_advice: [
        { title: '繰り返しに怒らない', detail: '同じことを何度も聞かれても、毎回初めて答えるような気持ちで接しましょう。' },
        { title: '否定せず受け入れる', detail: 'まず共感し、そっと話題を変える方法が効果的です。' },
        { title: '規則正しい生活リズム', detail: '毎日同じ時間に食事・就寝することで、混乱を減らせます。' },
        { title: '残っている能力を活かす', detail: '昔話を聞いたり、得意だったことを一緒に行うと情緒が安定します。' }
      ],
      concerns: '本人は漠然とした不安を感じています。安心できる環境づくりが大切です。',
      family_care: '一人で抱え込まず、地域包括支援センターやかかりつけ医に相談しましょう。'
    },
    lewy: {
      name: 'レビー小体型認知症',
      short: 'レビー小体型',
      color: '#A78BFA',
      icon: '🟣',
      prevalence: '約20% 第2位',
      description: '幻視・パーキンソン症状・認知機能の波が特徴です。薬の副作用が出やすく、医師との連携が特に重要です。',
      care_advice: [
        { title: '幻視を頭ごなしに否定しない', detail: '「そうなの、怖かったね」と共感してから安心させましょう。' },
        { title: '転倒に最大限注意', detail: '床の段差解消、手すり設置、滑りにくい靴が重要です。' },
        { title: '症状の波を記録する', detail: '日ご東の状態を記録することで、医師への情報提供に役立ちます。' },
        { title: '睡眠環境を整える', detail: '安全な寝室環境を整え、必要なら医師に相談を。' }
      ],
      concerns: '変動が激しいこと自体がこの病気の特徴だと理解することが重要です。',
      family_care: '抗精神病薬で症状が急激に悪化することがあります。処方変更前に専門医に確認を。'
    },
    vas: {
      name: '脳血管性認知症',
      short: '脳血管性',
      color: '#34D399',
      icon: '🟢',
      prevalence: '約20% 第2〜3位',
      description: '脳梗塞や脳出血などにより発症します。段階的に悪化する傾向があり、生活習慣病の管理が進行予防に直結します。',
      care_advice: [
        { title: '感情の爆発に冷静に対応', detail: '怒りが爆発しても言い返さず、嵐が過ぎるのを待ちましょう。' },
        { title: 'できることとできないことの差を理解', detail: '急かさず、時間をかけて待つことが大切です。' },
        { title: '生活習慣病の管理が最重要', detail: '服薬・食事・運動の管理を家族でサポートしましょう。' },
        { title: 'うつへの配慮', detail: '小さな活動を一緒に続けましょう。' }
      ],
      concerns: '脳卒中の再発が最大のリスクです。様子が違うと感じたら迷わず救急へ。',
      family_care: 'できたことを小さくほめることが本人の意欲につながります。'
    },
    ftd: {
      name: '前頭側頭型認知症',
      short: '前頭側頭型',
      color: '#FBBF24',
      icon: '🟡',
      prevalence: '約5〜10% 若年性に多い',
      description: '性格変化・社会的行動の障害が前面に出ます。記憶は比較的保たれる一方、人格や行動の変化が顕著です。',
      care_advice: [
        { title: '問題行動を「病気の症状」と理解する', detail: '「悪意がある」のではないと理解することが、介護者の精神的安定につながります。' },
        { title: 'ルーティンを徹底する', detail: '変化を嫌う傾向が強いので、環境を急に変えないようにしましょう。' },
        { title: '危険な行動への環境対策', detail: '車の鍵・財布・ハサミなどは安全な場所に保管を。' },
        { title: 'コミュニケーションを単純に', detail: '短い文章でゆっくり話し、選択肢を与えると伝わりやすいです。' }
      ],
      concerns: '性格が「変わってしまった」ことへの家族の戸惑いは非常に大きいです。専門家に気持ちを話せる場を。',
      family_care: '若年性認知症として50〜60代で発症することもあります。若年性認知症コーディネーターへの相談も。'
    }
  }.freeze
end
