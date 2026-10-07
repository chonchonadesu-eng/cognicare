import { Controller } from "@hotwired/stimulus"

// パスワードの表示・非表示を切り替えるコントローラー
export default class extends Controller {
  static targets = [ "input", "button" ]

  toggle() {
    if (this.inputTarget.type === "password") {
      this.inputTarget.type = "text"
      this.buttonTarget.textContent = "🔒" 
    } else {
      this.inputTarget.type = "password"
      this.buttonTarget.textContent = "👁️" 
    }
  }
}