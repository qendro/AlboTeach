import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
// Native checkboxes expose their partial-selection dash as a DOM property.
const SelectionCheckbox = {
  mounted() { this.syncSelection() },
  updated() { this.syncSelection() },
  syncSelection() {
    const input = this.el.querySelector('input[type="checkbox"]')
    const state = this.el.dataset.state
    input.checked = state === 'all'
    input.indeterminate = state === 'mixed'
    input.disabled = this.el.dataset.disabled === 'true'
    input.setAttribute('aria-checked', state === 'mixed' ? 'mixed' : String(state === 'all'))
  }
}
const liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}, hooks: {SelectionCheckbox}})
liveSocket.connect()
// Keep keyboard focus inside open dialogs and restore it on close.
let activeDialog = null
let previousFocus = null
const updateDialog = () => {
  const dialog = document.querySelector('[role="dialog"]')
  if (dialog && dialog !== activeDialog) {
    previousFocus = document.activeElement
    activeDialog = dialog
    requestAnimationFrame(() => dialog.querySelector('button, input, textarea, select')?.focus())
  } else if (!dialog && activeDialog) {
    activeDialog = null
    if (previousFocus?.isConnected) previousFocus.focus()
  }
}
new MutationObserver(updateDialog).observe(document.body, {childList: true, subtree: true})
document.addEventListener('keydown', e => {
  if (e.key !== 'Tab' || !activeDialog) return
  const nodes = [...activeDialog.querySelectorAll('button, input:not([type="hidden"]), textarea, select, a[href]')].filter(el => !el.disabled)
  const first = nodes[0], last = nodes[nodes.length - 1]
  if (e.shiftKey && document.activeElement === first) {e.preventDefault(); last?.focus()}
  if (!e.shiftKey && document.activeElement === last) {e.preventDefault(); first?.focus()}
})
