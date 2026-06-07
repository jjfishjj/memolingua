/**
 * muse.js — Web Bluetooth 串接真實腦波頭環 (Muse 2 / Muse S / NeuroSky)
 * 把模擬資料換成真實 EEG。瀏覽器需支援 Web Bluetooth (Chrome/Edge，HTTPS 或 localhost)。
 *
 * 用法：
 *   import { MuseClient } from './muse.js'
 *   const muse = new MuseClient()
 *   await muse.connect()                       // 跳出藍牙配對
 *   muse.onBands(bands => { ... })             // {delta,theta,alpha,beta,gamma}
 *   muse.onState(state => { ... })             // {engagement,cognitiveLoad,encodingStrength,relaxation,signalQuality}
 *   muse.disconnect()
 */

// ---- Muse BLE GATT UUID ----
const MUSE_SERVICE      = '0000fe8d-0000-1000-8000-00805f9b34fb'
const MUSE_CONTROL      = '273e0001-4c4d-454d-96be-f03bac821358'
const MUSE_EEG_CHANNELS = [
  '273e0003-4c4d-454d-96be-f03bac821358', // TP9  (左耳後)
  '273e0004-4c4d-454d-96be-f03bac821358', // AF7  (左前額)
  '273e0005-4c4d-454d-96be-f03bac821358', // AF8  (右前額)
  '273e0006-4c4d-454d-96be-f03bac821358', // TP10 (右耳後)
]
const SAMPLE_RATE = 256          // Muse 取樣率 256Hz
const FFT_SIZE    = 256          // 1 秒視窗
const BAND_RANGES = {
  delta: [0.5, 4], theta: [4, 8], alpha: [8, 12], beta: [12, 30], gamma: [30, 50],
}

export class MuseClient {
  constructor() {
    this.device = null
    this.eegChars = []
    this.controlChar = null
    this.buffers = MUSE_EEG_CHANNELS.map(() => [])   // 每通道環形緩衝
    this._bandCb = null
    this._stateCb = null
    this._raw = MUSE_EEG_CHANNELS.map(() => 0)
    this._loop = null
  }

  onBands(cb) { this._bandCb = cb; return this }
  onState(cb) { this._stateCb = cb; return this }

  async connect() {
    this.device = await navigator.bluetooth.requestDevice({
      filters: [{ services: [MUSE_SERVICE] }],
      optionalServices: [MUSE_SERVICE],
    })
    const server  = await this.device.gatt.connect()
    const service = await server.getPrimaryService(MUSE_SERVICE)

    // 控制通道：送出開始串流指令
    this.controlChar = await service.getCharacteristic(MUSE_CONTROL)
    await this.controlChar.startNotifications()

    // 訂閱 4 個 EEG 通道
    for (let i = 0; i < MUSE_EEG_CHANNELS.length; i++) {
      const ch = await service.getCharacteristic(MUSE_EEG_CHANNELS[i])
      await ch.startNotifications()
      ch.addEventListener('characteristicvaluechanged', e => this._onPacket(i, e.target.value))
      this.eegChars.push(ch)
    }

    await this._sendCmd('h')   // halt
    await this._sendCmd('p21') // preset 21 = 4ch EEG
    await this._sendCmd('d')   // start data
    this.device.addEventListener('gattserverdisconnected', () => this._loop && clearInterval(this._loop))

    // 每秒做一次 FFT → band power → 推導狀態
    this._loop = setInterval(() => this._analyze(), 1000)
    return true
  }

  async _sendCmd(str) {
    const bytes = [str.length, ...str.split('').map(c => c.charCodeAt(0)), 10]
    await this.controlChar.writeValue(new Uint8Array(bytes))
  }

  // Muse EEG 封包：12 個 12-bit 樣本 / 通道 / 封包
  _onPacket(chIdx, dataView) {
    const samples = decodeMuseEEG(dataView)
    const buf = this.buffers[chIdx]
    buf.push(...samples)
    if (buf.length > FFT_SIZE) buf.splice(0, buf.length - FFT_SIZE)
  }

  _analyze() {
    // 平均 4 通道的各頻段功率
    const acc = { delta:0, theta:0, alpha:0, beta:0, gamma:0 }
    let validCh = 0
    for (const buf of this.buffers) {
      if (buf.length < FFT_SIZE) continue
      validCh++
      const psd = computePSD(buf, SAMPLE_RATE)
      for (const band in BAND_RANGES) acc[band] += bandPower(psd, SAMPLE_RATE, FFT_SIZE, BAND_RANGES[band])
    }
    if (validCh === 0) return
    const bands = {}
    for (const b in acc) bands[b] = acc[b] / validCh

    // 訊號品質：用緩衝填滿率近似（實務可用 Muse 的 is_good 旗標）
    const signalQuality = Math.min(validCh / 4, 1)

    const state = deriveCognitiveState(bands, signalQuality)
    const varkBias = deriveVarkFromEEG(bands)

    this._bandCb && this._bandCb(bands)
    this._stateCb && this._stateCb({ ...state, ...varkBias, signalQuality })
  }

  disconnect() {
    this._loop && clearInterval(this._loop)
    this.device?.gatt?.connected && this.device.gatt.disconnect()
  }
}

// ---- DSP helpers ----
function decodeMuseEEG(dataView) {
  // bytes 2..19 = 12 個 12-bit 無號樣本，轉成 μV (中心 0)
  const out = []
  let bitOffset = 16   // 前 2 bytes 是序號
  for (let i = 0; i < 12; i++) {
    const byteIdx = bitOffset >> 3
    const bitIdx  = bitOffset & 7
    const raw = ((dataView.getUint8(byteIdx) << 8) | dataView.getUint8(byteIdx + 1))
    const val = (raw >> (4 - bitIdx)) & 0xFFF
    out.push((val - 2048) * 0.48828125)  // 轉 μV
    bitOffset += 12
  }
  return out
}

// 簡易 DFT 功率譜（樣本少時夠用；正式版建議用 fft.js）
function computePSD(signal, fs) {
  const N = signal.length
  const mean = signal.reduce((a, b) => a + b, 0) / N
  const psd = new Float32Array(N / 2)
  for (let k = 0; k < N / 2; k++) {
    let re = 0, im = 0
    for (let n = 0; n < N; n++) {
      const ang = (2 * Math.PI * k * n) / N
      const s = (signal[n] - mean)
      re += s * Math.cos(ang)
      im -= s * Math.sin(ang)
    }
    psd[k] = (re * re + im * im) / N
  }
  return psd
}

function bandPower(psd, fs, N, [lo, hi]) {
  const binHz = fs / N
  let p = 0
  for (let k = Math.floor(lo / binHz); k <= Math.min(Math.floor(hi / binHz), psd.length - 1); k++) p += psd[k]
  return p
}

// ---- 與 Demo 同步的推導公式 ----
export function deriveCognitiveState(b) {
  return {
    engagement:       clamp(b.beta / (b.alpha + b.theta + 1e-6), 0, 1),
    cognitiveLoad:    clamp((b.theta / (b.alpha + 1e-6)) * 0.7, 0, 1),
    encodingStrength: clamp((b.theta * b.gamma) / 420, 0, 1),
    relaxation:       clamp(b.alpha / (b.beta + 1e-6), 0, 1),
  }
}
export function deriveVarkFromEEG(b) {
  const raw = {
    v: b.alpha * 1.0,
    a: b.theta * 0.7 + b.alpha * 0.3,
    r: b.beta * 1.0,
    k: b.gamma * 0.6 + b.theta * 0.4,
  }
  const s = raw.v + raw.a + raw.r + raw.k || 1
  return { eeg_v: raw.v / s, eeg_a: raw.a / s, eeg_r: raw.r / s, eeg_k: raw.k / s }
}
const clamp = (x, a, b) => Math.max(a, Math.min(b, x))

/**
 * NeuroSky MindWave (TGAT) — 已提供 eSense 與 8 頻段，無需自己做 FFT
 * 透過 ThinkGear Connector (WebSocket :13854) 或 BLE
 */
export class NeuroSkyClient {
  constructor() { this.ws = null; this._stateCb = null; this._bandCb = null }
  onBands(cb) { this._bandCb = cb; return this }
  onState(cb) { this._stateCb = cb; return this }

  async connect(url = 'ws://127.0.0.1:13854') {
    this.ws = new WebSocket(url)
    this.ws.onopen = () => this.ws.send(JSON.stringify({ enableRawOutput: false, format: 'Json' }))
    this.ws.onmessage = e => {
      const d = JSON.parse(e.data)
      if (!d.eegPower) return
      const p = d.eegPower
      const bands = {
        delta: p.delta, theta: p.theta,
        alpha: p.lowAlpha + p.highAlpha,
        beta:  p.lowBeta + p.highBeta,
        gamma: p.lowGamma + p.highGamma,
      }
      this._bandCb && this._bandCb(bands)
      this._stateCb && this._stateCb({
        engagement:       (d.eSense?.attention ?? 50) / 100,
        relaxation:       (d.eSense?.meditation ?? 50) / 100,
        cognitiveLoad:    clamp(bands.theta / (bands.alpha + 1e-6) * 0.7, 0, 1),
        encodingStrength: clamp((bands.theta * bands.gamma) / 420, 0, 1),
        ...deriveVarkFromEEG(bands),
        signalQuality:    1 - (d.poorSignalLevel ?? 0) / 200,
      })
    }
  }
  disconnect() { this.ws?.close() }
}
