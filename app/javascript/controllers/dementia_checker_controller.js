import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "introScreen", "checkScreen", "resultScreen",
    "progressLabel", "checkedLabel", "progressFill",
    "categoryTabs", "catIcon", "catTitle", "selectedBadge", "symptomList",
    "prevBtn", "nextBtn",
    "resultSub", "topResult", "distribution", "detailCards",
    "aiSection", "aiContent",
    "hiddenCheckedIds", "saveForm"
  ]

  static values = {
    analyzeUrl:  String,
    categories:  Array,
    types:       Object,
  }

  // ---------- 初期化 ----------
  connect() {
    this.currentCategory = 0
    this.checked = {}
  }

  // ---------- イントロ → チェック画面 ----------
  startCheck() {
    this.showScreen("check")
    this.renderCategory()
  }

  // ---------- カテゴリ描画 ----------
  renderCategory() {
    const cat = this.categoriesValue[this.currentCategory]
    const total = this.categoriesValue.length

    // プログレス
    this.progressLabelTarget.textContent = `${this.currentCategory + 1} / ${total} カテゴリ`
    this.checkedLabelTarget.textContent  = `${this.checkedCount}項目チェック済み`
    this.progressFillTarget.style.width  = `${(this.currentCategory / total) * 100}%`

    // カテゴリヘッダー
    this.catIconTarget.textContent  = cat.icon
    this.catIconTarget.style.background = `${cat.color}20`
    this.catIconTarget.style.border     = `1px solid ${cat.color}40`
    this.catTitleTarget.textContent = cat.label

    // 選択バッジ
    const catChecked = cat.symptoms.filter(s => this.checked[s.id]).length
    if (catChecked > 0) {
      this.selectedBadgeTarget.textContent = `${catChecked}個選択`
      this.selectedBadgeTarget.classList.remove("dc-hidden")
    } else {
      this.selectedBadgeTarget.classList.add("dc-hidden")
    }

    // タブ描画
    this.categoryTabsTarget.innerHTML = this.categoriesValue.map((c, i) => {
      const cnt = c.symptoms.filter(s => this.checked[s.id]).length
      const active = i === this.currentCategory
      return `
        <button class="dc-tab ${active ? "dc-tab--active" : ""}"
                data-index="${i}"
                data-action="click->dementia-checker#jumpCategory">
          ${c.icon} ${c.label}
          ${cnt > 0 ? `<span class="dc-tab-badge">${cnt}</span>` : ""}
        </button>
      `
    }).join("")

    // 症状リスト
    this.symptomListTarget.innerHTML = cat.symptoms.map(sym => `
      <div class="dc-symptom ${this.checked[sym.id] ? "dc-symptom--checked" : ""}"
           data-id="${sym.id}"
           data-action="click->dementia-checker#toggleSymptom">
        <div class="dc-checkbox ${this.checked[sym.id] ? "dc-checkbox--checked" : ""}">
          ${this.checked[sym.id] ? "✓" : ""}
        </div>
        <span class="dc-symptom-text">${sym.ja}</span>
      </div>
    `).join("")

    // ボタン表示制御
    this.prevBtnTarget.style.visibility = this.currentCategory > 0 ? "visible" : "hidden"
    const isLast = this.currentCategory === this.categoriesValue.length - 1
    this.nextBtnTarget.textContent = isLast ? "結果を見る 🔍" : "次のカテゴリへ →"
  }

  // ---------- 症状トグル ----------
  toggleSymptom(e) {
    const el = e.currentTarget
    const id = el.dataset.id
    this.checked[id] = !this.checked[id]
    this.renderCategory()
  }

  // ---------- タブジャンプ ----------
  jumpCategory(e) {
    this.currentCategory = parseInt(e.currentTarget.dataset.index)
    this.renderCategory()
  }

  // ---------- 前へ / 次へ ----------
  prevCategory() {
    if (this.currentCategory > 0) {
      this.currentCategory--
      this.renderCategory()
    }
  }

  nextCategory() {
    if (this.currentCategory < this.categoriesValue.length - 1) {
      this.currentCategory++
      this.renderCategory()
    } else {
      this.showResults()
    }
  }

  // ---------- 結果表示 ----------
  async showResults() {
    const scores  = this.calculateScores()
    const results = this.sortResults(scores)

    this.showScreen("result")
    this.renderResults(results)
    this.injectCheckedIdsToForm()
  }

  // 有料ユーザー用保存フォームの input(hidden) へ選択されたIDを流し込む
  injectCheckedIdsToForm() {
    const checkedIds = Object.entries(this.checked)
      .filter(([, v]) => v)
      .map(([k]) => k)

    let form = this.hasSaveFormTarget ? this.saveFormTarget : null
    
    if (!form && this.hasHiddenCheckedIdsTarget) {
      form = this.hiddenCheckedIdsTarget.closest('form')
    }

    if (form) {
      form.querySelectorAll('.dynamic-checked-id').forEach(el => el.remove())
      
      checkedIds.forEach(id => {
        const hiddenInput = document.createElement('input')
        hiddenInput.type = 'hidden'
        hiddenInput.name = 'checked_ids[]'
        hiddenInput.value = id
        hiddenInput.classList.add('dynamic-checked-id')
        form.appendChild(hiddenInput)
      })
      
      console.log("🔥 フォームにIDを仕込みました:", checkedIds)
    } else {
      console.error("🚨 保存フォームが見つかりませんでした！")
    }
  }

  calculateScores() {
    const scores = { alz: 0, vas: 0, lewy: 0, ftd: 0 }
    this.categoriesValue.forEach(cat => {
      cat.symptoms.forEach(sym => {
        if (this.checked[sym.id]) {
          Object.entries(sym.weights).forEach(([type, w]) => { scores[type] += w })
        }
      })
    })
    return scores
  }

  sortResults(scores) {
    const total = Object.values(scores).reduce((a, b) => a + b, 0)
    return Object.entries(scores)
      .sort((a, b) => b[1] - a[1])
      .map(([key, val]) => ({
        key, score: val,
        pct: total > 0 ? Math.round((val / total) * 100) : 0,
        ...this.typesValue[key]
      }))
  }

  renderResults(results) {
    const n = this.checkedCount
    this.resultSubTarget.textContent = `${n}項目のチェックをもとに分析しました`

    // トップ結果
    const top = results[0]
    if (top.pct > 0) {
      this.topResultTarget.innerHTML = `
        <div class="dc-top-result-inner" style="border-color:${top.color}30; background: linear-gradient(135deg,${top.color}15,${top.color}08)">
          <p class="dc-top-label" style="color:${top.color}">最も特徴が一致する可能性</p>
          <div class="dc-top-main">
            <span class="dc-top-icon">${top.icon}</span>
            <div>
              <p class="dc-top-name">${top.name}</p>
              <p class="dc-top-prev">${top.prevalence}</p>
            </div>
            <span class="dc-top-pct" style="color:${top.color}">${top.pct}%</span>
          </div>
          <p class="dc-top-desc">${top.description}</p>
        </div>
      `
    }

    // %グラフ
    this.distributionTarget.innerHTML = results.map(r => `
      <div class="dc-bar-row">
        <div class="dc-bar-label">
          <span>${r.icon} ${r.short}</span>
          <span style="color:${r.color};font-weight:600">${r.pct}%</span>
        </div>
        <div class="dc-bar-track">
          <div class="dc-bar-fill" style="width:${r.pct}%;background:${r.color}"></div>
        </div>
      </div>
    `).join("")

    // 詳細カード
    this.detailCardsTarget.innerHTML = results
      .filter(r => r.pct > 0)
      .map(r => this.buildDetailCard(r))
      .join("")
  }

  buildDetailCard(r) {
    const adviceHtml = (r.care_advice || []).map(a => `
      <div class="dc-advice-item" style="border-left-color:${r.color}">
        <p class="dc-advice-title">${a.title}</p>
        <p class="dc-advice-detail">${a.detail}</p>
      </div>
    `).join("")

    return `
      <div class="dc-detail-card">
        <div class="dc-detail-header"
             style="background:linear-gradient(135deg,${r.color}12,${r.color}06);border-color:${r.color}25"
             data-action="click->dementia-checker#toggleDetail"
             data-key="${r.key}">
          <span>${r.icon}</span>
          <div class="dc-detail-name-wrap">
            <p class="dc-detail-name">${r.name}</p>
            <p class="dc-detail-prev">${r.prevalence}</p>
          </div>
          <span style="color:${r.color};font-weight:700">${r.pct}%</span>
          <span class="dc-chevron" data-key="${r.key}">▼</span>
        </div>
        <div class="dc-detail-body dc-hidden" data-key="${r.key}">
          <p class="dc-detail-desc">${r.description}</p>
          <p class="dc-care-label" style="color:${r.color}">💡 ケアのポイント</p>
          ${adviceHtml}
          <div class="dc-concern-box">
            <p class="dc-concern-label">💙 本人の気持ちを理解するために</p>
            <p>${r.concerns}</p>
          </div>
          <div class="dc-family-box">
            <p class="dc-family-label">🤝 家族・介護者へ</p>
            <p>${r.family_care}</p>
          </div>
        </div>
      </div>
    `
  }

  toggleDetail(e) {
    const key  = e.currentTarget.dataset.key
    const body = this.detailCardsTarget.querySelector(`.dc-detail-body[data-key="${key}"]`)
    body.classList.toggle("dc-hidden")
  }

  // ---------- リセット ----------
  reset() {
    this.currentCategory = 0
    this.checked = {}
    this.showScreen("intro")
  }

  // ---------- ユーティリティ ----------
  showScreen(name) {
    this.introScreenTarget.classList.toggle("dc-hidden", name !== "intro")
    this.checkScreenTarget.classList.toggle("dc-hidden", name !== "check")
    this.resultScreenTarget.classList.toggle("dc-hidden", name !== "result")
    window.scrollTo({ top: 0, behavior: "smooth" })
  }

  get checkedCount() {
    return Object.values(this.checked).filter(Boolean).length
  }
}