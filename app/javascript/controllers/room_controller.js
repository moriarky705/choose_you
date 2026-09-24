import { Controller } from "@hotwired/stimulus"
import QRCode from "qrcode"
import consumer from "../channels/consumer"

// Real-time updates for room management
export default class extends Controller {
  static values = { roomId: String, owner: Boolean, selfId: String, ownerId: String }
  static targets = ["participants", "selectionList", "countInput", "selectionHeader", "selectionCount", "inviteUrl", "copyFeedback", "copyButton", "shareButton", "qrPanel", "qrCanvas", "selectionStatus", "selectionSubmit", "participantCount", "selectionEmpty", "selfResult", "roulette", "selectionForm", "selectionError", "eligibleHint", "historyList", "historyCard", "historyData", "connectionDot", "connectionLabel", "refreshButton"]

  // Connection and initialization
  connect() {
    console.log('Room controller connecting...', this.roomIdValue)
    this.drawInFlight = false
    this.pendingHistory = null
    this.revealPendingId = null
    this.qrGenerated = false
    this.selfRemoved = false
    this.connectionConfig = new ConnectionConfig()
    this.setConnectionState('connecting')
    this.initializeFromServerRenderedState()
    this.setupRealtimeConnection()
    this.animateSelectionResults()
    this.setupShareButton()
  }

  disconnect() {
    this.cleanup()
  }

  initializeFromServerRenderedState() {
    this.currentParticipants = this.hasParticipantsTarget
      ? Array.from(this.participantsTarget.querySelectorAll('[data-participant-name]')).map((el) => ({ id: el.dataset.participantId || '', name: el.dataset.participantName }))
      : []

    this.shownSelectionId = (this.hasSelectionListTarget && this.selectionListTarget.dataset.selectionId) || ''

    const history = this.readServerHistory()
    this.latestNumber = (history[0] && typeof history[0].number === 'number') ? history[0].number : 0
    this.renderHistory(history)
  }

  readServerHistory() {
    if (!this.hasHistoryDataTarget) return []

    try {
      const parsed = JSON.parse(this.historyDataTarget.textContent || '[]')
      return Array.isArray(parsed) ? parsed : []
    } catch (error) {
      console.log('Failed to parse history data:', error)
      return []
    }
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
    this.setConnectionState('connected')
    this.stopPolling()
  }

  handleConnectionLost() {
    console.log('❌ ActionCable disconnected for room:', this.roomIdValue)
    this.setConnectionState('disconnected')
    this.startPolling()
  }

  handleConnectionRejected() {
    console.log('🚫 ActionCable connection rejected for room:', this.roomIdValue)
    this.setConnectionState('disconnected')
    this.startPolling()
  }

  // Live connection status badge (dot + label + title) and manual-refresh visibility
  setConnectionState(state) {
    const dotClass = {
      connecting: 'bg-gray-300',
      connected: 'bg-green-400',
      disconnected: 'bg-amber-400'
    }[state] || 'bg-gray-300'

    const label = {
      connecting: '接続中…',
      connected: 'オンライン',
      disconnected: '再接続中…'
    }[state] || '接続中…'

    if (this.hasConnectionDotTarget) {
      this.connectionDotTarget.classList.remove('bg-gray-300', 'bg-green-400', 'bg-amber-400')
      this.connectionDotTarget.classList.add(dotClass)

      if (this.connectionDotTarget.parentElement) {
        this.connectionDotTarget.parentElement.title = label
      }
    }

    if (this.hasConnectionLabelTarget) {
      this.connectionLabelTarget.textContent = label
    }

    if (this.hasRefreshButtonTarget) {
      this.refreshButtonTarget.classList.toggle('hidden', state !== 'disconnected')
    }
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

    if (!this.selfRemoved && !this.ownerValue && this.selfIdValue && !list.some((p) => p.id === this.selfIdValue)) {
      this.selfRemoved = true
      window.location.reload()
      return
    }

    console.log('🎨 Rendering participants:', list.length, 'participants')
    const renderer = new ParticipantRenderer(this.selfIdValue, this.ownerValue, this.ownerIdValue)
    this.participantsTarget.innerHTML = renderer.render(list)

    if (this.hasParticipantCountTarget) {
      this.participantCountTarget.textContent = list.length
    }

    this.updateEligible()
  }

  // Eligible pool / count input helpers (owner controls)
  includeOwnerCheckbox() {
    return this.element.querySelector('input[name="include_owner"][type="checkbox"]')
  }

  excludeWinnersCheckbox() {
    return this.element.querySelector('input[name="exclude_winners"][type="checkbox"]')
  }

  includeOwnerChecked() {
    const checkbox = this.includeOwnerCheckbox()
    return checkbox ? checkbox.checked : true
  }

  excludeWinnersChecked() {
    const checkbox = this.excludeWinnersCheckbox()
    return checkbox ? checkbox.checked : false
  }

  eligibleCount() {
    let pool = this.currentParticipants || []

    if (!this.includeOwnerChecked()) {
      if (this.ownerIdValue) {
        pool = pool.filter((p) => p.id !== this.ownerIdValue)
      } else {
        // レガシールームでは owner_id が空になりうるため、常に先頭に並ぶオーナーを除外する
        pool = pool.slice(1)
      }
    }

    if (this.excludeWinnersChecked()) {
      const winnerIds = new Set(
        (this.history || [])
          .flatMap((entry) => entry.selected || [])
          .map((s) => s.id)
          .filter((id) => Boolean(id))
      )
      pool = pool.filter((p) => !winnerIds.has(p.id))
    }

    return pool.length
  }

  updateEligible() {
    if (!this.hasCountInputTarget) return

    const max = this.eligibleCount()
    const clampedMax = max > 0 ? max : 1

    this.countInputTarget.max = clampedMax

    const current = parseInt(this.countInputTarget.value, 10) || 1
    this.countInputTarget.value = Math.min(Math.max(current, 1), clampedMax)

    if (this.hasSelectionSubmitTarget && !this.drawInFlight) {
      this.selectionSubmitTarget.disabled = max <= 0
      this.selectionSubmitTarget.classList.toggle('opacity-60', max <= 0)
      this.selectionSubmitTarget.classList.toggle('cursor-not-allowed', max <= 0)
    }

    if (this.hasEligibleHintTarget) {
      this.eligibleHintTarget.textContent = max <= 0 ? '抽選対象がいません' : `抽選対象: ${max}人`
    }
  }

  stepCount(event) {
    if (!this.hasCountInputTarget) return

    const step = parseInt(event.currentTarget.dataset.step, 10) || 0
    const max = Math.max(parseInt(this.countInputTarget.max, 10) || this.eligibleCount() || 1, 1)
    const current = parseInt(this.countInputTarget.value, 10) || 1

    this.countInputTarget.value = Math.min(Math.max(current + step, 1), max)
  }

  preset(event) {
    if (!this.hasCountInputTarget) return

    const max = Math.max(parseInt(this.countInputTarget.max, 10) || this.eligibleCount() || 1, 1)
    const preset = event.currentTarget.dataset.preset

    let value = 1
    if (preset === 'half') value = Math.max(1, Math.floor(max / 2))
    if (preset === 'all') value = max

    this.countInputTarget.value = value
  }

  // History rendering
  renderHistory(history) {
    this.history = history || []

    if (this.hasHistoryCardTarget) {
      this.historyCardTarget.classList.toggle('hidden', this.history.length === 0)
    }

    if (this.hasHistoryListTarget) {
      const renderer = new HistoryRenderer(this.selfIdValue)
      this.historyListTarget.innerHTML = renderer.render(this.history)
    }

    this.updateEligible()
  }

  // 抽選結果と履歴を同時に受け取った際、履歴カードでの先出しによりルーレットの結果が
  // 事前に分かってしまわないよう、新規（未表示）の抽選結果に付随する履歴は
  // revealSelection で結果を表示した後に描画する
  receiveSelectionUpdate(selectionData, history) {
    const id = selectionData && selectionData.id
    const number = selectionData && typeof selectionData.number === 'number' ? selectionData.number : null

    if (number !== null && number < this.latestNumber) {
      // 複数オーナータブ等の競合で届いた、より古い抽選結果は履歴ごと無視する
      return
    }

    if (number !== null) {
      this.latestNumber = Math.max(this.latestNumber, number)
    }

    if (id && id === this.revealPendingId) {
      // 同じ抽選のリベール（ルーレット演出～結果表示）がまだ進行中
      // （オーナー自身のJSONレスポンスとブロードキャストが競合するケースなど）。
      // ここで描画するとネタバレになるため、最新の履歴を保留分として差し替えるだけにする
      this.pendingHistory = history || null
      return
    }

    const isNewSelection = Boolean(id) && id !== this.shownSelectionId

    if (isNewSelection) {
      this.pendingHistory = history || null
    } else if (history) {
      this.renderHistory(history)
    }

    if (selectionData) {
      this.renderSelection(selectionData)
    }
  }

  renderSelection(selection) {
    if (selection.id && selection.id === this.shownSelectionId) return
    this.shownSelectionId = selection.id
    // 新しい抽選が割り込んできたら、古いルーレットの id は「リベール待ち」から外れる
    this.revealPendingId = selection.id

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

    if (this.pendingHistory) {
      this.renderHistory(this.pendingHistory)
      this.pendingHistory = null
    }

    if (this.revealPendingId === selection.id) {
      this.revealPendingId = null
    }

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

    this.drawInFlight = true
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
          this.receiveSelectionUpdate({ ...data.selection, animate: true }, data.history)
        } else {
          if (data.history) this.renderHistory(data.history)
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
    this.drawInFlight = false

    if (this.hasSelectionStatusTarget) {
      this.selectionStatusTarget.classList.add('hidden')
      this.selectionStatusTarget.classList.remove('inline-flex')
    }

    if (this.hasSelectionSubmitTarget) {
      this.selectionSubmitTarget.value = '抽選開始'
    }

    // 抽選中に固定していたdisabled状態を、現在の抽選対象人数に基づいて再計算する
    this.updateEligible()
  }

  // Copy functionality
  async copyInvite() {
    if (!this.hasInviteUrlTarget) return

    const copyHandler = new CopyHandler(this)
    await copyHandler.copyText(this.inviteUrlTarget.textContent.trim())
  }

  // Share sheet
  setupShareButton() {
    if (this.hasShareButtonTarget && navigator.share) {
      this.shareButtonTarget.classList.remove('hidden')
    }
  }

  async shareInvite() {
    if (!this.hasInviteUrlTarget || !navigator.share) return

    const url = this.inviteUrlTarget.textContent.trim()

    try {
      await navigator.share({ title: 'Choose You', text: '抽選ルームに参加してください', url })
    } catch (error) {
      if (error.name === 'AbortError') return

      console.log('Share failed:', error)
      const copyHandler = new CopyHandler(this)
      copyHandler.showFeedback('共有できませんでした', 2000, 'text-red-600')
    }
  }

  // QR code
  toggleQr(event) {
    if (!this.hasQrPanelTarget) return

    const isHidden = this.qrPanelTarget.classList.toggle('hidden')
    event.currentTarget.setAttribute('aria-expanded', (!isHidden).toString())

    if (!isHidden) this.generateQr()
  }

  async generateQr() {
    if (this.qrGenerated || !this.hasQrCanvasTarget || !this.hasInviteUrlTarget) return

    const url = this.inviteUrlTarget.textContent.trim()

    try {
      await QRCode.toCanvas(this.qrCanvasTarget, url, { width: 200, margin: 1 })
      this.qrGenerated = true
    } catch (error) {
      console.log('QR code generation failed:', error)
      if (this.hasQrPanelTarget) {
        const message = document.createElement('p')
        message.className = 'text-sm text-red-600'
        message.textContent = 'QRコードを生成できませんでした'
        this.qrPanelTarget.appendChild(message)
      }
    }
  }

  // Manual refresh
  refreshUpdates() {
    console.log('🔄 Manual refresh requested')
    this.fetchUpdates()
  }

  // Leave room (participants only)
  confirmLeave(event) {
    if (!window.confirm('このルームから退出しますか？')) event.preventDefault()
  }

  // Remove participant (owner only)
  async removeParticipant(event) {
    const { participantId, participantName } = event.currentTarget.dataset
    if (!window.confirm(`「${participantName}」さんをルームから削除しますか？`)) return

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    const path = `/rooms/${encodeURIComponent(this.roomIdValue)}/participants/${encodeURIComponent(participantId)}`

    try {
      const response = await fetch(path, {
        method: 'DELETE',
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': csrfToken
        }
      })

      if (!response.ok) {
        let message = '削除できませんでした'
        try {
          const data = await response.json()
          if (data.error) message = data.error
        } catch (parseError) {
          console.log('Failed to parse remove participant error response:', parseError)
        }
        window.alert(message)
      }
    } catch (error) {
      console.log('Remove participant request failed:', error)
      window.alert('削除できませんでした')
    }
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
        number: data.selection.number,
        selected: data.selection.selected,
        count: data.selection.count,
        animate: false,
        history: data.history
      })
    } else if (data.history) {
      this.controller.renderHistory(data.history)
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
      this.controller.receiveSelectionUpdate(
        { id: data.id, number: data.number, selected: data.selected, count: data.count, animate: data.animate },
        data.history
      )

      // 抽選後に参加者リストが消える問題の対策
      // 現在の参加者リストが空でなければ維持する
      if (this.controller.hasParticipantsTarget &&
          this.controller.participantsTarget.children.length === 0) {
        console.log('🔄 Participants list disappeared after selection, fetching updates...')
        this.controller.fetchUpdates()
      }
    } else if (data.history) {
      this.controller.renderHistory(data.history)
    }
  }
}

// Participant list rendering
class ParticipantRenderer {
  constructor(selfId, isOwner, ownerId) {
    this.selfId = selfId
    this.isOwner = isOwner
    this.ownerId = ownerId
  }

  render(participants) {
    return participants.map((p, index) => {
      const isSelf = Boolean(this.selfId) && p.id === this.selfId
      const safeName = this.escapeHtml(p.name)
      const safeId = this.escapeHtml(p.id || '')
      const canRemove = this.isOwner && p.id && p.id !== this.ownerId

      return `<div class="flex items-center p-3 ${isSelf ? 'bg-blue-50 hover:bg-blue-100' : 'bg-gray-50 hover:bg-gray-100'} rounded-lg transition-colors" data-participant-id="${safeId}" data-participant-name="${safeName}">
        <div class="w-10 h-10 bg-blue-600 rounded-full flex items-center justify-center text-white font-medium mr-3">
          ${index + 1}
        </div>
        <span class="text-gray-900 font-medium">${safeName}</span>
        ${isSelf ? '<span class="ml-2 text-xs text-blue-600 font-medium">（あなた）</span>' : ''}
        ${canRemove ? `<button type="button" class="ml-auto text-gray-400 hover:text-red-600 p-1" data-action="click->room#removeParticipant" data-participant-id="${safeId}" data-participant-name="${safeName}" aria-label="${safeName}さんを削除">×</button>` : ''}
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

// Draw history rendering
class HistoryRenderer {
  constructor(selfId) {
    this.selfId = selfId
  }

  render(history) {
    return history.map((entry) => {
      const names = (entry.selected || []).map((s) => {
        const safeName = this.escapeHtml(s.name)
        const isSelf = Boolean(this.selfId) && s.id === this.selfId
        return isSelf ? `<strong>${safeName}</strong>` : safeName
      }).join('、')

      return `<li><span class="font-medium">第${entry.number}回</span>：${names}</li>`
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
