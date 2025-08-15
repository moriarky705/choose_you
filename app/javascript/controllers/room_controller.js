import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

// Connects to data-controller="room"
export default class extends Controller {
  static values = { roomId: String, owner: Boolean }
  static targets = ["participants", "selectionList", "countInput", "selectionHeader", "inviteUrl", "copyFeedback", "copyButton"]

  connect() {
    console.log('Room controller connecting...', this.roomIdValue)
    this.isProduction = window.location.hostname.includes('onrender.com')
    
    // ActionCableでリアルタイム更新を試行
    this.subscription = consumer.subscriptions.create({ channel: 'RoomChannel', room_id: this.roomIdValue }, {
      connected: () => {
        console.log('✅ ActionCable connected for room:', this.roomIdValue)
        // ActionCableが接続されたらポーリングを停止
        if (this.pollingTimer) {
          clearInterval(this.pollingTimer)
          this.pollingTimer = null
          console.log('⏸️ Polling stopped - ActionCable active')
        }
      },
      disconnected: () => {
        console.log('❌ ActionCable disconnected for room:', this.roomIdValue)
        // 本番環境（Redis利用時）でも接続が切れた場合はポーリングにフォールバック
        this.startPolling()
      },
      received: (data) => {
        console.log('📡 ActionCable received:', data)
        if (data.type === 'participants') {
          this.renderParticipants(data.participants)
        } else if (data.type === 'selection') {
          if (data.selected) this.renderSelection(data.selected, data.count)
        }
      }
    })
    
    // 開発環境でのみポーリングを開始（本番環境はActionCableを優先）
    if (!this.isProduction) {
      console.log('🔄 Starting polling for development environment')
      this.startPolling()
    } else {
      console.log('🚀 Production mode - relying on ActionCable with Redis')
    }
  }
  
  startPolling() {
    // 既存のポーリングがあれば停止
    if (this.pollingTimer) {
      clearInterval(this.pollingTimer)
    }
    
    // 開発環境でのポーリング間隔（30秒）
    const interval = 30000
    
    console.log(`🔄 Starting polling every ${interval/1000} seconds for room:`, this.roomIdValue)
    
    this.pollingTimer = setInterval(() => {
      console.log('📊 Polling for updates...')
      this.fetchUpdates()
    }, interval)
  }
  
  async fetchUpdates() {
    try {
      const response = await fetch(`/rooms/${this.roomIdValue}/updates`, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        if (data.participants) {
          this.renderParticipants(data.participants)
        }
        if (data.selection) {
          this.renderSelection(data.selection.selected, data.selection.count)
        }
      }
    } catch (error) {
      console.log('Polling update failed:', error)
    }
  }

  disconnect() {
    if (this.subscription) consumer.subscriptions.remove(this.subscription)
    if (this.pollingTimer) {
      clearInterval(this.pollingTimer)
      this.pollingTimer = null
    }
  }

  renderParticipants(list) {
    if (!this.hasParticipantsTarget) return
    this.participantsTarget.innerHTML = list.map((p, index) => 
      `<div class="flex items-center p-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors">
        <div class="w-10 h-10 bg-blue-600 rounded-full flex items-center justify-center text-white font-medium mr-3">
          ${index + 1}
        </div>
        <span class="text-gray-900 font-medium">${p.name}</span>
      </div>`
    ).join('')
  }

  renderSelection(selected, count) {
    if (!this.hasSelectionListTarget) return
    this.selectionListTarget.innerHTML = selected.map((p, index) => 
      `<div class="flex items-center p-4 bg-amber-50 border border-amber-200 rounded-lg">
        <div class="w-10 h-10 bg-amber-600 rounded-full flex items-center justify-center text-white font-bold mr-3">
          <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
            <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.196-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"></path>
          </svg>
        </div>
        <span class="text-gray-900 font-semibold">${p.name}</span>
      </div>`
    ).join('')
    if (this.hasSelectionHeaderTarget) {
      if (this.selectionHeaderTarget.hidden) this.selectionHeaderTarget.hidden = false
      this.selectionHeaderTarget.textContent = '抽選結果'
    }
  }

  async copyInvite() {
    if (!this.hasInviteUrlTarget) return
    const text = this.inviteUrlTarget.textContent.trim()
    const show = (msg, ms=1500, cls='text-green-600') => {
      if (!this.hasCopyFeedbackTarget) return
      this.copyFeedbackTarget.textContent = msg
      this.copyFeedbackTarget.className = `text-xs ${cls}`
      this.copyFeedbackTarget.style.display = 'inline'
      clearTimeout(this._copyTimer)
      this._copyTimer = setTimeout(() => { this.copyFeedbackTarget.style.display = 'none'; }, ms)
    }
    const showOk = () => show('コピーしました', 1500, 'text-green-600')
    const showErr = (err) => { console.error('Copy failed', err); show('コピー失敗', 2000, 'text-red-600') }
    // Try Clipboard API first
    if (navigator.clipboard && navigator.clipboard.writeText) {
      try {
        await navigator.clipboard.writeText(text)
        showOk()
        return
      } catch (e) {
        // fall through
        showErr(e)
      }
    }
    // Fallback using temporary textarea
    try {
      const ta = document.createElement('textarea')
      ta.value = text
      ta.style.position = 'fixed'
      ta.style.top = '-1000px'
      document.body.appendChild(ta)
      ta.focus()
      ta.select()
      const ok = document.execCommand('copy')
      document.body.removeChild(ta)
      ok ? showOk() : showErr('execCommand returned false')
    } catch (e) {
      showErr(e)
    }
  }
  
  // 手動更新メソッド
  refreshUpdates() {
    console.log('🔄 Manual refresh requested')
    this.fetchUpdates()
  }
}
