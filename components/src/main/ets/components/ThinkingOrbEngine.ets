/**
 * thinking-orbs working/orbits（MIT © Jakub Antalik）。
 * 手机上按参考 64 逻辑像素出点；轨道平面预计算，帧内只投影、不分配。
 */

export class OrbDot {
  x: number = 0
  y: number = 0
  z: number = 0
  r: number = 0
  white: number = 0
  a: number = 1
}

class OrbitPlane {
  ro: number = 0
  ux: number = 0
  uy: number = 0
  uz: number = 0
  vx: number = 0
  vy: number = 0
  vz: number = 0
  speed: number = 0
  h2: number = 0
}

export class ThinkingOrbEngine {
  /** 手机 64vp：比网页 12×40 疏，环仍可读 */
  static readonly ORBIT_N: number = 7
  static readonly GHOST_N: number = 16
  static readonly PARTICLES: number = 2
  static readonly SPEED: number = 1.885
  static readonly GHOST_R: number = 1.05
  static readonly GHOST_A: number = 0.48
  static readonly PART_R: number = 1.45
  static readonly PART_R_DEPTH: number = 1.7
  static readonly RS_POW: number = 0.6
  static readonly R_MIN: number = 0.45
  /** 7 * (16 + 2) */
  static readonly EXPECTED_DOTS: number = 126
  static readonly GLOBE_RINGS: number = 8
  static readonly GLOBE_LON: number = 16
  static readonly WAVE_RINGS: number = 8
  static readonly WAVE_LON: number = 16

  private planes: OrbitPlane[] = []
  private buffer: OrbDot[] = []
  private lastSize: number = -1

  static hashD(a: number, b: number): number {
    const h = Math.sin(a * 12.9898 + b * 78.233) * 43758.5453
    return h - Math.floor(h)
  }

  static radiusScale(size: number): number {
    return Math.pow(size / 300, ThinkingOrbEngine.RS_POW)
  }

  static inkRgba(white: number, alpha: number, dark: boolean): string {
    const w = Math.min(1, Math.max(0, white))
    const g = Math.round((dark ? 1 - w : w) * 255)
    const steps = Math.round(alpha * 8)
    const a = steps / 8
    return 'rgba(' + g + ',' + g + ',' + g + ',' + a + ')'
  }

  /** 兼容测试：无状态一帧 */
  static frameOrbits(size: number, t: number): OrbDot[] {
    const eng = new ThinkingOrbEngine()
    return eng.fillFrame(size, t, 'working')
  }

  static frameGlobe(size: number, t: number): OrbDot[] {
    const eng = new ThinkingOrbEngine()
    return eng.fillFrame(size, t, 'searching')
  }

  static frameWave(size: number, t: number): OrbDot[] {
    const eng = new ThinkingOrbEngine()
    return eng.fillFrame(size, t, 'listening')
  }

  static speedOf(mode: string): number {
    if (mode === 'searching') {
      return 2.015
    }
    if (mode === 'listening') {
      return 4.388
    }
    return ThinkingOrbEngine.SPEED
  }

  static angleDelta(a: number, b: number): number {
    return Math.atan2(Math.sin(a - b), Math.cos(a - b))
  }

  fillFrame(size: number, t: number, mode: string = 'working'): OrbDot[] {
    if (mode === 'searching') {
      return this.fillGlobe(size, t)
    }
    if (mode === 'listening') {
      return this.fillWave(size, t)
    }
    return this.fillOrbits(size, t)
  }

  private fillOrbits(size: number, t: number): OrbDot[] {
    this.ensurePlanes(size)
    const cx = size / 2
    const cy = size / 2
    const rs = ThinkingOrbEngine.radiusScale(size)
    const st = Math.sin(0.3)
    const ct = Math.cos(0.3)
    const yaw = t * 0.12
    const sy = Math.sin(yaw)
    const cyw = Math.cos(yaw)
    let n = 0
    for (let orb = 0; orb < ThinkingOrbEngine.ORBIT_N; orb++) {
      const p = this.planes[orb]
      const ro = p.ro
      for (let k = 0; k < ThinkingOrbEngine.GHOST_N; k++) {
        const a = (k / ThinkingOrbEngine.GHOST_N) * 2 * Math.PI
        const d = this.buffer[n]
        ThinkingOrbEngine.projectInto(
          (p.ux * Math.cos(a) + p.vx * Math.sin(a)) * ro,
          (p.uy * Math.cos(a) + p.vy * Math.sin(a)) * ro,
          (p.uz * Math.cos(a) + p.vz * Math.sin(a)) * ro,
          sy, cyw, st, ct, cx, cy, 1, d
        )
        const depth = (d.z / ro + 1) / 2
        d.r = Math.max(ThinkingOrbEngine.R_MIN, ThinkingOrbEngine.GHOST_R * rs)
        d.white = 0.72
        d.a = ThinkingOrbEngine.GHOST_A * (0.4 + 0.6 * depth)
        n++
      }
      for (let m = 0; m < ThinkingOrbEngine.PARTICLES; m++) {
        const a = t * p.speed + (m / ThinkingOrbEngine.PARTICLES) * 2 * Math.PI + p.h2 * 6
        const d = this.buffer[n]
        ThinkingOrbEngine.projectInto(
          (p.ux * Math.cos(a) + p.vx * Math.sin(a)) * ro,
          (p.uy * Math.cos(a) + p.vy * Math.sin(a)) * ro,
          (p.uz * Math.cos(a) + p.vz * Math.sin(a)) * ro,
          sy, cyw, st, ct, cx, cy, 1, d
        )
        const depth = (d.z / ro + 1) / 2
        d.r = Math.max(ThinkingOrbEngine.R_MIN,
          (ThinkingOrbEngine.PART_R + ThinkingOrbEngine.PART_R_DEPTH * depth) * rs)
        d.white = 0.3 - 0.22 * depth
        d.a = 1
        n++
      }
    }
    this.used = n
    return this.buffer
  }

  private fillGlobe(size: number, t: number): OrbDot[] {
    this.ensureLattice(size, 200)
    const cx = size / 2
    const cy = size / 2
    const radius = (size / 2) * 0.82
    const tilt = 0.4 + 0.06 * Math.sin(t * 0.35)
    const spin = 0.5
    const st = Math.sin(tilt)
    const ct = Math.cos(tilt)
    const yaw = t * spin
    const sy = Math.sin(yaw)
    const cyw = Math.cos(yaw)
    const scan = t * (spin + (1.7 - spin) * 4.08)
    const rs = ThinkingOrbEngine.radiusScale(size)
    const dimBase = 0.45
    let n = 0
    for (let li = 0; li <= ThinkingOrbEngine.GLOBE_RINGS; li++) {
      const lat = -Math.PI / 2 + (li / ThinkingOrbEngine.GLOBE_RINGS) * Math.PI
      const cosLat = Math.cos(lat)
      const sinLat = Math.sin(lat)
      const lonCount = Math.max(1, Math.round(Math.abs(cosLat) * ThinkingOrbEngine.GLOBE_LON))
      for (let lj = 0; lj < lonCount; lj++) {
        const lon = (lj / lonCount) * 2 * Math.PI
        const d = this.buffer[n]
        ThinkingOrbEngine.projectInto(
          cosLat * Math.cos(lon), sinLat, cosLat * Math.sin(lon),
          sy, cyw, st, ct, cx, cy, radius, d
        )
        const depth = (d.z + 1) / 2
        const delta = ThinkingOrbEngine.angleDelta(lon + t * spin, scan)
        const boost = Math.exp(-(delta * delta) / 0.18) * Math.max(0, d.z)
        d.r = Math.max(ThinkingOrbEngine.R_MIN, (0.6 + 1.7 * depth + boost) * rs)
        d.white = 0.62 - 0.54 * depth
        d.a = dimBase + (1 - dimBase) * Math.min(1, boost)
        n++
      }
    }
    this.used = n
    return this.buffer
  }

  private fillWave(size: number, t: number): OrbDot[] {
    this.ensureLattice(size, 200)
    const cx = size / 2
    const cy = size / 2
    const R = (size / 2) * 0.874
    const st = Math.sin(0.38)
    const ct = Math.cos(0.38)
    const yaw = t * 0.18
    const sy = Math.sin(yaw)
    const cyw = Math.cos(yaw)
    const rs = ThinkingOrbEngine.radiusScale(size)
    let n = 0
    for (let ri = 0; ri <= ThinkingOrbEngine.WAVE_RINGS; ri++) {
      const lat = -Math.PI / 2 + (ri / ThinkingOrbEngine.WAVE_RINGS) * Math.PI
      const cosLat = Math.cos(lat)
      const sinLat = Math.sin(lat)
      const w = 0.62 * Math.sin(t * 2.1 - ri * 0.52) + 0.38 * Math.sin(t * 1.27 + ri * 0.83)
      const rr = R * (0.88 + 0.105 * w)
      const lonCount = Math.max(1, Math.round(Math.abs(cosLat) * ThinkingOrbEngine.WAVE_LON))
      const crest = Math.max(0, w)
      for (let lj = 0; lj < lonCount; lj++) {
        const lon = (lj / lonCount) * 2 * Math.PI
        const d = this.buffer[n]
        ThinkingOrbEngine.projectInto(
          cosLat * Math.cos(lon) * rr, sinLat * rr, cosLat * Math.sin(lon) * rr,
          sy, cyw, st, ct, cx, cy, 1, d
        )
        const depth = (d.z / R + 1) / 2
        d.r = Math.max(ThinkingOrbEngine.R_MIN, (0.6 + 1.7 * depth) * (1 + 0.4 * crest) * rs)
        d.white = 0.66 - 0.56 * depth - 0.1 * crest
        d.a = 1
        n++
      }
    }
    this.used = n
    return this.buffer
  }

  private used: number = 0

  usedCount(): number {
    return this.used
  }

  private ensureLattice(size: number, cap: number): void {
    if (this.buffer.length >= cap && this.lastSize === size) {
      return
    }
    this.lastSize = size
    while (this.buffer.length < cap) {
      this.buffer.push(new OrbDot())
    }
  }

  private ensurePlanes(size: number): void {
    if (this.lastSize === size && this.planes.length === ThinkingOrbEngine.ORBIT_N) {
      return
    }
    this.lastSize = size
    const R = (size / 2) * 0.82
    this.planes = []
    this.buffer = []
    const total = ThinkingOrbEngine.EXPECTED_DOTS
    for (let i = 0; i < total; i++) {
      this.buffer.push(new OrbDot())
    }
    for (let orb = 0; orb < ThinkingOrbEngine.ORBIT_N; orb++) {
      const h1 = ThinkingOrbEngine.hashD(orb, 1.7)
      const h2 = ThinkingOrbEngine.hashD(orb, 5.2)
      const h3 = ThinkingOrbEngine.hashD(orb, 8.9)
      const th = h1 * 2 * Math.PI
      const phi = Math.acos(2 * h2 - 1)
      const nx = Math.sin(phi) * Math.cos(th)
      const ny = Math.cos(phi)
      const nz = Math.sin(phi) * Math.sin(th)
      let ux = -ny
      let uy = nx
      const uz = 0
      const ul = Math.max(1e-6, Math.sqrt(ux * ux + uy * uy))
      ux = ux / ul
      uy = uy / ul
      const p = new OrbitPlane()
      p.ro = R * (0.45 + 0.52 * h1)
      p.ux = ux
      p.uy = uy
      p.uz = uz
      p.vx = ny * uz - nz * uy
      p.vy = nz * ux - nx * uz
      p.vz = nx * uy - ny * ux
      p.speed = (0.25 + 0.55 * h3) * (h3 > 0.5 ? 1 : -1)
      p.h2 = h2
      this.planes.push(p)
    }
  }

  private static projectInto(
    x: number, y: number, z: number,
    sy: number, cyw: number, st: number, ct: number,
    cx: number, cy: number, scale: number, d: OrbDot
  ): void {
    const x1 = x * cyw + z * sy
    const z1 = -x * sy + z * cyw
    const y1 = y * ct - z1 * st
    const z2 = y * st + z1 * ct
    d.x = cx + x1 * scale
    d.y = cy - y1 * scale
    d.z = z2
  }
}
