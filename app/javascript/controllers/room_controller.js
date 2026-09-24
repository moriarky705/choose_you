import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

// Real-time updates for room management
export default class extends Controller {
  static values = { roomId: String, owner: Boolean, selfId: String }
  static targets = ["participants", "selectionList", "countInput", "selectionHeader", "selectionCount", "inviteUrl", "copyFeedback", "copyButton", "selectionStatus", "selectionSubmit", "participantCount", "selectionEmpty", "selfResult", "roulette", "selectionForm", "selectionError"]

  // Connection and initialization
  connect() {
    console.log('Room controller connecting...', this.roomIdValue)
    this.connectionConfig = new ConnectionConfig()
    this.initializeFromServerRenderedState()
    this.setupRealtimeConnection()
    this.animateSelectionResults()
  }

  disconnect() {
    this.cleanup()
  }

  initializeFromServerRenderedState() {
    this.currentParticipants = this.hasParticipantsTarget
      ? Array.from(this.participantsTarget.querySelectorAll('[data-participant-name]')).map((el) => ({ name: el.dataset.participantName }))
      : []

    this.shownSelectionId = (this.hasSelectionListTarget && this.selectionListTarget.dataset.selectionId) || ''
  }

  // Real-time connection management
  setupRealtimeConnection() {
    this.subscription = consumer.subscriptions.create(
      { channel: 'RoomChannel', room_id: this.roomIdValue },
      {
        connected: () => this.handleConnectionSuccess(),
        disconnected: () => this.handleConnectionLost(),
        rejected: () => this.handleConnectionRejected(),
        received: (data) => this.handleMessage(data)
      }
    )

    if (this.connectionConfig.shouldStartPolling()) {
      this.startPolling()
    }
  }

  handleConnectionSuccess() {
    console.log('✅ ActionCable connected for room:', this.roomIdValue)
    this.stopPolling()
  }

  handleConnectionLost() {
    console.log('❌ ActionCable disconnected for room:', this.roomIdValue)
    this.startPolling()
  }

  handleConnectionRejected() {
    console.log('🚫 ActionCable connection rejected for room:', this.roomIdValue)
    this.startPolling()
  }

  handleMessage(data) {
    console.log('📡 ActionCable received:', data)

    const messageHandler = new MessageHandler(this)
    messageHandler.process(data)
  }

  // Polling fallback mechanism
  startPolling() {
    this.stopPolling()

    const interval = this.connectionConfig.pollingInterval
    console.log(`🔄 Starting polling every ${interval/1000} seconds for room:`, this.roomIdValue)

    this.pollingTimer = setInterval(() => {
      console.log('� Polling for updates...')
      this.fetchUpdates()
    }, interval)
  }

  stopPolling() {
    if (this.pollingTimer) {
      clearInterval(this.pollingTimer)
      this.pollingTimer = null
      console.log('⏸️ Polling stopped - ActionCable active')
    }
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
        const messageHandler = new MessageHandler(this)
        messageHandler.processPollingData(data)
      }
    } catch (error) {
      console.log('Polling update failed:', error)
    }
  }

  // UI rendering methods
  renderParticipants(list) {
    this.currentParticipants = list

    if (!this.hasParticipantsTarget) return

    console.log('🎨 Rendering participants:', list.length, 'participants')
    const renderer = new ParticipantRenderer(this.selfIdValue)
    this.participantsTarget.innerHTML = renderer.render(list)

    if (this.hasParticipantCountTarget) {
      this.participantCountTarget.textContent = list.length
    }
  }

  renderSelection(selection) {
    if (selection.id && selection.id === this.shownSelectionId) return
    this.shownSelectionId = selection.id

    if (this._rouletteCancel) this._rouletteCancel()
    if (this.hasRouletteTarget) this.rouletteTarget.classList.add('hidden')
    if (this.hasSelectionListTarget) this.selectionListTarget.classList.remove('hidden')

    const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches

    if (selection.animate && !prefersReducedMotion && this.currentParticipants.length > 1) {
      this.playRoulette(selection.selected).then(() => this.revealSelection(selection, true))
    } else {
      this.revealSelection(selection, selection.animate)
    }
  }

  revealSelection(selection, celebrate) {
    this.finishSelection()
    if (!this.hasSelectionListTarget) return

    const renderer = new SelectionRenderer(this.selfIdValue)
    this.selectionListTarget.innerHTML = renderer.render(selection.selected)
    this.selectionListTarget.classList.remove('hidden')
    this.updateSelectionHeader(selection.selected.length)

    if (this.hasSelectionEmptyTarget) {
      this.selectionEmptyTarget.classList.add('hidden')
    }

    this.renderSelfResult(selection.selected)
    this.animateSelectionResults()

    if (celebrate) this.celebrateSelection()
  }

  renderSelfResult(selected) {
    if (!this.hasSelfResultTarget) return

    if (!this.selfIdValue) {
      this.selfResultTarget.classList.add('hidden')
      return
    }

    const won = selected.some((p) => p.id === this.selfIdValue)
    this.selfResultTarget.classList.remove('hidden')
    this.selfResultTarget.textContent = won ? '🎉 あなたが選ばれました！' : '今回は選ばれませんでした'
    this.selfResultTarget.classList.toggle('bg-amber-100', won)
    this.selfResultTarget.classList.toggle('text-amber-800', won)
    this.selfResultTarget.classList.toggle('bg-gray-100', !won)
    this.selfResultTarget.classList.toggle('text-gray-600', !won)
  }

  // Roulette build-up before revealing the real winners
  playRoulette(selected) {
    if (this._rouletteCancel) this._rouletteCancel()

    if (!this.hasRouletteTarget || this.currentParticipants.length === 0) return Promise.resolve()

    const names = this.currentParticipants.map((p) => p.name)

    this.rouletteTarget.classList.remove('hidden')
    if (this.hasSelectionListTarget) this.selectionListTarget.classList.add('hidden')
    if (this.hasSelfResultTarget) this.selfResultTarget.classList.add('hidden')
    if (this.hasSelectionEmptyTarget) this.selectionEmptyTarget.classList.add('hidden')

    return new Promise((resolve) => {
      let cancelled = false
      this._rouletteCancel = () => { cancelled = true }

      const totalDuration = 2200
      let elapsed = 0
      let delay = 60

      const tick = () => {
        if (cancelled) return

        elapsed += delay

        if (elapsed >= totalDuration) {
          const winnerName = (selected[0] && selected[0].name) || ''
          this.rouletteTarget.textContent = winnerName

          window.setTimeout(() => {
            if (cancelled) return
            this.rouletteTarget.classList.add('hidden')
            if (this.hasSelectionListTarget) this.selectionListTarget.classList.remove('hidden')
            resolve()
          }, 300)
          return
        }

        const randomName = names[Math.floor(Math.random() * names.length)]
        this.rouletteTarget.textContent = randomName
        delay *= 1.12
        window.setTimeout(tick, delay)
      }

      tick()
    })
  }

  updateSelectionHeader(count) {
    if (this.hasSelectionHeaderTarget && this.selectionHeaderTarget.hidden) {
      this.selectionHeaderTarget.hidden = false
    }
    if (this.hasSelectionCountTarget) {
      this.selectionCountTarget.textContent = `当選者 ${count}名`
    }
  }

  animateSelectionResults() {
    if (!this.hasSelectionListTarget || window.matchMedia('(prefers-reduced-motion: reduce)').matches) return

    this.selectionListTarget.querySelectorAll('[data-selection-result]').forEach((card, index) => {
      card.animate(
        [
          { opacity: 0, transform: 'translateY(12px) scale(0.98)' },
          { opacity: 1, transform: 'translateY(0) scale(1)' }
        ],
        { duration: 450, delay: index * 80, easing: 'cubic-bezier(0.22, 1, 0.36, 1)', fill: 'both' }
      )
    })
  }

  celebrateSelection() {
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return

    const burst = document.createElement('div')
    burst.setAttribute('aria-hidden', 'true')
    burst.style.cssText = 'position:fixed;inset:0;overflow:hidden;pointer-events:none;z-index:50'
    document.body.appendChild(burst)

    const colors = ['#F59E0B', '#10B981', '#6366F1', '#EC4899', '#06B6D4']
    for (let index = 0; index < 36; index += 1) {
      const particle = document.createElement('span')
      const horizontal = (Math.random() - 0.5) * 520
      const vertical = 220 + Math.random() * 360
      const rotation = (Math.random() - 0.5) * 720
      const size = 6 + Math.random() * 5

      particle.style.cssText = [
        'position:absolute',
        'left:50%',
        'top:22%',
        `width:${size}px`,
        `height:${size * 1.6}px`,
        `background:${colors[index % colors.length]}`,
        'border-radius:2px'
      ].join(';')
      burst.appendChild(particle)
      particle.animate(
        [
          { transform: 'translate(-50%, -50%) rotate(0deg)', opacity: 1 },
          { transform: `translate(calc(-50% + ${horizontal}px), ${vertical}px) rotate(${rotation}deg)`, opacity: 0 }
        ],
        { duration: 1200 + Math.random() * 500, delay: Math.random() * 180, easing: 'cubic-bezier(0.22, 1, 0.36, 1)', fill: 'both' }
      )
    }

    window.setTimeout(() => burst.remove(), 1900)
  }

  startSelection(event) {
    if (this.hasSelectionErrorTarget) {
      this.selectionErrorTarget.classList.add('hidden')
      this.selectionErrorTarget.textContent = ''
    }

    this.showSelectionSpinner()

    if (!window.fetch || !this.hasSelectionFormTarget) return

    event.preventDefault()
    this.submitSelectionForm()
  }

  showSelectionSpinner() {
    if (this.hasSelectionStatusTarget) {
      this.selectionStatusTarget.classList.remove('hidden')
      this.selectionStatusTarget.classList.add('inline-flex')
    }

    if (this.hasSelectionSubmitTarget) {
      this.selectionSubmitTarget.disabled = true
      this.selectionSubmitTarget.classList.add('opacity-60', 'cursor-not-allowed')
      this.selectionSubmitTarget.value = '抽選中…'
    }
  }

  async submitSelectionForm() {
    const form = this.selectionFormTarget
    const formData = new FormData(form)
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      const response = await fetch(form.action, {
        method: 'POST',
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': csrfToken
        },
        body: formData
      })

      if (!response.ok) {
        let message = '抽選に失敗しました'
        try {
          const data = await response.json()
          if (data.error) message = data.error
        } catch (parseError) {
          console.log('Failed to parse selection error response:', parseError)
        }
        this.showSelectionError(message)
        this.finishSelection()
        return
      }

      try {
        const data = await response.json()
        if (data.selection) {
          // ブロードキャストが届かない/遅延する場合に備え、レスポンス自体から描画する
          // （このあとブロードキャストが届いても id 一致で二重描画されない）
          this.renderSelection({ ...data.selection, animate: true })
        } else {
          this.finishSelection()
        }
      } catch (parseError) {
        console.log('Failed to parse selection response:', parseError)
        this.finishSelection()
      }
    } catch (error) {
      console.log('Selection request failed:', error)
      this.showSelectionError('通信に失敗しました。もう一度お試しください')
      this.finishSelection()
    }
  }

  showSelectionError(message) {
    if (!this.hasSelectionErrorTarget) return

    this.selectionErrorTarget.textContent = message
    this.selectionErrorTarget.classList.remove('hidden')
  }

  finishSelection() {
    if (this.hasSelectionStatusTarget) {
      this.selectionStatusTarget.classList.add('hidden')
      this.selectionStatusTarget.classList.remove('inline-flex')
    }

    if (this.hasSelectionSubmitTarget) {
      this.selectionSubmitTarget.disabled = false
      this.selectionSubmitTarget.classList.remove('opacity-60', 'cursor-not-allowed')
      this.selectionSubmitTarget.value = '抽選開始'
    }
  }

  // Copy functionality
  async copyInvite() {
    if (!this.hasInviteUrlTarget) return

    const copyHandler = new CopyHandler(this)
    await copyHandler.copyText(this.inviteUrlTarget.textContent.trim())
  }

  // Manual refresh
  refreshUpdates() {
    console.log('🔄 Manual refresh requested')
    this.fetchUpdates()
  }

  // Cleanup
  cleanup() {
    if (this.subscription) consumer.subscriptions.remove(this.subscription)
    this.stopPolling()
  }
}

// Configuration for connection behavior
class ConnectionConfig {
  constructor() {
    this.isProduction = window.location.hostname.includes('onrender.com')
    this.pollingInterval = 30000
  }

  shouldStartPolling() {
    return !this.isProduction
  }
}

// Message handling for real-time updates
class MessageHandler {
  constructor(controller) {
    this.controller = controller
  }

  process(data) {
    switch (data.type) {
      case 'ping':
        this.handlePing(data)
        break
      case 'participants':
        this.handleParticipantsUpdate(data)
        break
      case 'selection':
        this.handleSelectionUpdate(data)
        break
    }
  }

  processPollingData(data) {
    if (data.participants) {
      this.handleParticipantsUpdate({ participants: data.participants })
    }
    if (data.selection) {
      this.handleSelectionUpdate({
        id: data.selection.id,
        selected: data.selection.selected,
        count: data.selection.count,
        animate: false
      })
    }
  }

  handlePing(data) {
    console.log('🏓 ActionCable ping received:', data.message)
  }

  handleParticipantsUpdate(data) {
    console.log('👥 Updating participants list:', data.participants.length, 'participants')
    this.controller.renderParticipants(data.participants)
  }

  handleSelectionUpdate(data) {
    if (data.selected) {
      this.controller.renderSelection({ id: data.id, selected: data.selected, count: data.count, animate: data.animate })

      // 抽選後に参加者リストが消える問題の対策
      // 現在の参加者リストが空でなければ維持する
      if (this.controller.hasParticipantsTarget &&
          this.controller.participantsTarget.children.length === 0) {
        console.log('🔄 Participants list disappeared after selection, fetching updates...')
        this.controller.fetchUpdates()
      }
    }
  }
}

// Participant list rendering
class ParticipantRenderer {
  constructor(selfId) {
    this.selfId = selfId
  }

  render(participants) {
    return participants.map((p, index) => {
      const isSelf = Boolean(this.selfId) && p.id === this.selfId
      const safeName = this.escapeHtml(p.name)

      return `<div class="flex items-center p-3 ${isSelf ? 'bg-blue-50' : 'bg-gray-50'} rounded-lg hover:bg-gray-100 transition-colors" data-participant-name="${safeName}">
        <div class="w-10 h-10 bg-blue-600 rounded-full flex items-center justify-center text-white font-medium mr-3">
          ${index + 1}
        </div>
        <span class="text-gray-900 font-medium">${safeName}</span>
        ${isSelf ? '<span class="ml-2 text-xs text-blue-600 font-medium">（あなた）</span>' : ''}
      </div>`
    }).join('')
  }

  escapeHtml(unsafe) {
    return unsafe
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#039;")
  }
}

// Selection results rendering
class SelectionRenderer {
  constructor(selfId) {
    this.selfId = selfId
  }

  render(selected) {
    return selected.map((p) => {
      const isSelf = Boolean(this.selfId) && p.id === this.selfId
      const safeName = this.escapeHtml(p.name)

      return `<div class="flex items-center p-4 bg-amber-50 border border-amber-200 rounded-lg ${isSelf ? 'ring-2 ring-amber-400' : ''}" data-selection-result data-selection-name="${safeName}">
        <div class="w-10 h-10 bg-amber-600 rounded-full flex items-center justify-center text-white font-bold mr-3">
          ${this.renderStarIcon()}
        </div>
        <span class="text-gray-900 font-semibold">${safeName}</span>
        ${isSelf ? '<span class="ml-2 text-xs text-amber-700 font-medium">（あなた）</span>' : ''}
      </div>`
    }).join('')
  }

  renderStarIcon() {
    return `<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
      <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.196-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"></path>
    </svg>`
  }

  escapeHtml(unsafe) {
    return unsafe
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#039;")
  }
}

// Copy to clipboard functionality
class CopyHandler {
  constructor(controller) {
    this.controller = controller
  }

  async copyText(text) {
    try {
      await this.tryClipboardAPI(text)
      this.showSuccess()
    } catch (error) {
      try {
        await this.tryFallbackMethod(text)
        this.showSuccess()
      } catch (fallbackError) {
        this.showError(fallbackError)
      }
    }
  }

  async tryClipboardAPI(text) {
    if (!navigator.clipboard?.writeText) {
      throw new Error('Clipboard API not available')
    }
    await navigator.clipboard.writeText(text)
  }

  async tryFallbackMethod(text) {
    const textarea = document.createElement('textarea')
    textarea.value = text
    textarea.style.position = 'fixed'
    textarea.style.top = '-1000px'

    document.body.appendChild(textarea)
    textarea.focus()
    textarea.select()

    const success = document.execCommand('copy')
    document.body.removeChild(textarea)

    if (!success) {
      throw new Error('execCommand returned false')
    }
  }

  showSuccess() {
    this.showFeedback('コピーしました', 1500, 'text-green-600')
  }

  showError(error) {
    console.error('Copy failed', error)
    this.showFeedback('コピー失敗', 2000, 'text-red-600')
  }

  showFeedback(message, duration, className) {
    if (!this.controller.hasCopyFeedbackTarget) return

    const target = this.controller.copyFeedbackTarget
    target.textContent = message
    target.className = `text-xs ${className}`
    target.style.display = 'inline'

    clearTimeout(this.controller._copyTimer)
    this.controller._copyTimer = setTimeout(() => {
      target.style.display = 'none'
    }, duration)
  }
}
