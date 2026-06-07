# Apple Human Interface Guidelines — iOS 26 Reference

> **Purpose**: Referensi lengkap prinsip-prinsip Apple HIG untuk development iOS 26.
> Digunakan sebagai pedoman desain dan coding untuk project ini.
>
> **Apple HIG URL**: https://developer.apple.com/design/human-interface-guidelines/
> **SwiftUI Docs**: https://developer.apple.com/documentation/swiftui
> **SF Symbols App**: https://developer.apple.com/sf-symbols/
> **WWDC25 — What's New in SwiftUI**: https://developer.apple.com/videos/play/wwdc2025/256/
> **WWDC25 — Build a SwiftUI App with the New Design**: https://developer.apple.com/videos/play/wwdc2025/323/
> **WWDC25 — Meet Liquid Glass**: https://developer.apple.com/videos/play/wwdc2025/219/
>
> **Last Updated**: May 2026 (iOS 26 / WWDC25 — fully verified)
> **Sample Reference**: Wishlist — Planning Travel in a SwiftUI App (Apple official sample, downloaded)

---

## Table of Contents

1. [Design Foundations](#1-design-foundations)
2. [Typography](#2-typography)
3. [Color System](#3-color-system)
4. [Liquid Glass — iOS 26 Material System](#4-liquid-glass--ios-26-material-system)
5. [SF Symbols 7](#5-sf-symbols-7)
6. [Layout & Spacing](#6-layout--spacing)
7. [Navigation Patterns — iOS 26 Updated](#7-navigation-patterns--ios-26-updated)
8. [Toolbar APIs — iOS 26 Complete Guide](#8-toolbar-apis--ios-26-complete-guide)
9. [Scroll APIs — iOS 26 Updated](#9-scroll-apis--ios-26-updated)
10. [TabView — iOS 26 Updated](#10-tabview--ios-26-updated)
11. [Lists & Forms](#11-lists--forms)
12. [Sheets & Modals](#12-sheets--modals)
13. [Empty States](#13-empty-states)
14. [Search](#14-search)
15. [Materials & Backgrounds](#15-materials--backgrounds)
16. [Gestalt Theory — Applied to iOS Design](#16-gestalt-theory--applied-to-ios-design)
17. [Design Principles Applied](#17-design-principles-applied)
18. [Quick Reference Card — iOS 26](#18-quick-reference-card--ios-26)
19. [Apple Documentation Links](#19-apple-documentation-links)

---

## 1. Design Foundations

### 1.1 Core Principles (Pilar Utama)

| Principle | Definition | Implikasi untuk Developer |
|---|---|---|
| **Clarity** | Interface harus bersih, presisi, tidak cluttered. Konten adalah hero. | Jangan tambah elemen dekoratif yang tidak punya fungsi. |
| **Consistency** | Gunakan komponen standar dan pola interaksi bawaan iOS. | User sudah tahu cara pakai NavigationStack, List, Form — jangan reinvent. |
| **Deference** | UI mengalah untuk konten. Minimalis, beri ruang. | Hindari warna background yang lebih bold dari konten. UI = bingkai, bukan lukisan. |
| **Depth** | Layer, shadow, motion menciptakan hierarki dan konteks. | Gunakan `.sheet` untuk modal, bukan custom overlay. Liquid Glass menangani depth. |

> **iOS 26 Context**: Liquid Glass adalah evolusi dari prinsip Depth. Ia memberikan *functional separation* antara navigation layer dan content layer secara visual — bukan dekorasi, tapi information hierarchy yang diimplementasikan sebagai material.

### 1.2 Accessibility — Bukan Opsional

Accessibility adalah **baseline requirement**. Setiap fitur harus diakses oleh semua user.

| Requirement | Minimum Standard | SwiftUI Implementation |
|---|---|---|
| **Touch target** | 44×44 pt | Semua button/interactive element harus memenuhi |
| **Dynamic Type** | xSmall → AX5 | Gunakan semantic text styles (`.headline`, `.body`, dll), JANGAN hardcode size |
| **VoiceOver** | Semua elemen interaktif harus readable | Tambahkan `.accessibilityLabel()` jika elemen ambigu |
| **Color contrast** | Normal text ≥ 4.5:1, Large text ≥ 3:1, UI ≥ 3:1 | Gunakan semantic colors, test dengan Accessibility Inspector |
| **Reduce Motion** | Animasi harus bisa di-disable | Gunakan `@Environment(\.accessibilityReduceMotion)` |
| **Reduce Transparency** | Solid fallback harus tersedia | Liquid Glass otomatis fallback ke solid material |
| **Color independence** | Warna BUKAN satu-satunya indikator | Selalu pasangkan warna dengan ikon + teks |

**Testing Method**: Xcode → Accessibility Inspector → Audit

### 1.3 Tes Checklist per Screen

```
□ Dynamic Type: render dari xSmall sampai AX5 tanpa overlap
□ Dark Mode: semua warna adaptif
□ VoiceOver: bisa navigasi tanpa melihat layar
□ Increase Contrast: teks tetap terbaca (Liquid Glass solid fallback)
□ Reduce Transparency: solid fallback berfungsi
□ Reduce Motion: zoom transitions dan spring animations di-disable
□ Rotate: landscape layout tidak rusak (atau landscape disabled)
□ Touch target: minimum 44×44pt
```

---

## 2. Typography

### 2.1 SF Pro — System Font iOS 26

iOS 26 menggunakan **SF Pro** sebagai system font. Ini adalah variable font dengan dua optical size:
- **SF Pro Text**: Optimized untuk ≤19pt
- **SF Pro Display**: Optimized untuk ≥20pt

SwiftUI menangani optical sizing secara otomatis saat kamu pakai semantic text styles.

### 2.2 Text Styles — Specification Table

Berikut spesifikasi di **default Dynamic Type setting ("Large")**:

| SwiftUI Style | Size (pt) | Weight | Leading | Emphasized Weight | Gunakan untuk |
|---|---|---|---|---|---|
| `.largeTitle` | 34 | Regular | ~41 | Bold | Screen title (Navigation) |
| `.title` | 28 | Regular | ~34 | Bold | Primary section title |
| `.title2` | 22 | Regular | ~28 | Bold | Secondary section title |
| `.title3` | 20 | Semibold | ~25 | Heavy | Tertiary section / prominent label |
| `.headline` | 17 | **Semibold** | ~22 | Heavy | Primary label dalam row/cell |
| `.body` | 17 | Regular | ~22 | Semibold | Default content text |
| `.callout` | 16 | Regular | ~21 | Semibold | Important info, quotes |
| `.subheadline` | 15 | Regular | ~20 | Semibold | Secondary label |
| `.footnote` | 13 | Regular | ~18 | Semibold | Tertiary text, disclaimers |
| `.caption` | 12 | Regular | ~16 | Medium | Image descriptions, small metadata |
| `.caption2` | 11 | Regular | ~13 | Medium | Smallest text, timestamps |

> **BARU DI IOS 26 — Emphasized Weights**: Apple menambahkan spesifikasi "emphasized weight" untuk setiap text style. Ini adalah weight yang sistem gunakan untuk `.bold()` modifier pada masing-masing style. Misal: `.largeTitle.bold()` menggunakan weight **Bold** bukan Semibold.

> **PENTING**: `.headline` dan `.body` **ukurannya sama (17pt)** tapi beda weight! Headline = Semibold, Body = Regular.

### 2.3 Variable Font Width — BARU iOS 26

iOS 26 memanfaatkan kemampuan variable font dari SF Pro untuk mengekspresikan konteks lebih kaya:

```swift
// Font Width variants — dari yang paling sempit ke paling lebar
Text("SECTION HEADER")
    .fontWidth(.compressed)  // Paling sempit

Text("Category Label")
    .fontWidth(.condensed)   // Sedikit lebih sempit dari default

Text("Normal Text")
    .fontWidth(.standard)    // Default (tidak perlu ditulis)

Text("TITLE DISPLAY")
    .fontWidth(.expanded)    // Lebih lebar, lebih monumental — dipakai Apple di Wishlist
```

**Kapan pakai:**
- `.expanded` → navigation titles, section headers yang ingin terasa monumental/premium (lihat Wishlist app dari Apple — semua judul navigasi pakai `.fontWidth(.expanded)`)
- `.condensed` → metadata kecil, label dalam card yang ruangnya terbatas
- `.compressed` → ONLY untuk kasus khusus ruang sangat sempit

**Contoh dari Wishlist app (Apple official sample):**
```swift
Text("Wishlist")
    .font(.system(size: 34, weight: .medium))
    .fontWidth(.expanded)
    .bold()

Text(trip.name)
    .font(.title)
    .fontWidth(.expanded)
    .fontWeight(.medium)
```

### 2.4 Small Caps

```swift
// Small caps — for metadata labels, section identifiers
Text("RECENTLY ADDED")
    .font(.footnote.smallCaps())   // Preferred
    .font(.subheadline.smallCaps())

// Lowercase to small caps
Text("section title")
    .textCase(.uppercase)   // All caps — simpler approach
```

### 2.5 Rules — Apa yang BOLEH dan TIDAK BOLEH

| ✅ Do | ❌ Don't |
|---|---|
| `.font(.headline)` | `.font(.system(size: 17, weight: .semibold))` |
| Biarkan system menentukan size | Hardcode `.font(.system(size: 14))` |
| `.fontWidth(.expanded)` untuk display titles | Gunakan `.expanded` pada body text |
| `.monospacedDigit()` untuk angka berubah (score, timer) | Biarkan angka menggunakan proportional spacing |
| Test di Dynamic Type AX5 | Anggap user selalu pakai default size |
| `.fontWeight(.medium)` untuk subtle emphasis | Skip weight variation entirely |

### 2.6 Hierarchy Pattern — 3 Level Rule

```
Level 1 (Primary):   .headline / .title3  — apa yang user HARUS lihat
Level 2 (Secondary): .subheadline          — detail pendukung
Level 3 (Metadata):  .caption / .footnote  — info tambahan
```

---

## 3. Color System

### 3.1 Semantic Colors — Yang HARUS Dipakai

```swift
// Text Colors — via .foregroundStyle()
.primary         → Color(.label)                  // Teks utama, judul
.secondary       → Color(.secondaryLabel)         // Teks pendukung, metadata
.tertiary        → Color(.tertiaryLabel)          // placeholder, disabled
                   Color(.quaternaryLabel)        // watermark-level text

// Background Colors
Color(.systemBackground)                          // Base background
Color(.secondarySystemBackground)                 // Grouped content area
Color(.tertiarySystemBackground)                  // Nested grouped content
Color(.systemGroupedBackground)                   // List background
Color(.secondarySystemGroupedBackground)          // List cell background
```

### 3.2 System Colors — Palette Adaptif

| Color | Light | Dark | Semantic Usage |
|---|---|---|---|
| `.red` | #FF3B30 | #FF453A | Destructive, error, overdue |
| `.orange` | #FF9500 | #FF9F0A | Warning, in-progress |
| `.yellow` | #FFCC00 | #FFD60A | Caution, attention |
| `.green` | #34C759 | #30D158 | Success, complete |
| `.mint` | #00C7BE | #63E6E2 | Fresh, new |
| `.teal` | #30B0C7 | #40CBE0 | Information link |
| `.cyan` | #32ADE6 | #64D2FF | Informational |
| `.blue` | #007AFF | #0A84FF | **System tint**, interactive, links |
| `.indigo` | #5856D6 | #5E5CE6 | Premium, special |
| `.purple` | #AF52DE | #BF5AF2 | Creative |
| `.pink` | #FF2D55 | #FF375F | Feminine, love |
| `.brown` | #A2845E | #AC8E68 | Earth, natural |

### 3.3 iOS 26 — Color dengan Liquid Glass

Liquid Glass memperkenalkan translucent backgrounds. Ini berarti:

1. **Jangan override toolbar/nav bar** dengan `toolbarBackground` — warna kamu akan mengganggu Liquid Glass
2. **`.foregroundStyle(.primary)` tetap bekerja** di atas Liquid Glass — sistem menangani contrast otomatis
3. **Custom tint colors** bekerja dengan glass: `.tint(.accentColor)` pada button dengan `.buttonStyle(.glass)` memberi tinted glass
4. **Hindari `.white` / `.black` hardcoded** di context translucent — tidak adaptif

```swift
// ✅ iOS 26 correct — tint works with glass
Button("Action") { }
    .buttonStyle(.glassProminent)
    .tint(.blue)

// ❌ iOS 26 wrong — custom toolbar background breaks glass
.toolbarBackground(Color.blue, for: .navigationBar)  // Don't do this in iOS 26
```

### 3.4 Contrast Requirements (WCAG 2.1 AA)

| Elemen | Minimum Ratio | Cara Cek |
|---|---|---|
| Normal text (< 18pt) | **4.5 : 1** | Accessibility Inspector |
| Large text (≥ 18pt or ≥ 14pt bold) | **3 : 1** | Accessibility Inspector |
| UI components (icons, borders) | **3 : 1** | Accessibility Inspector |

### 3.5 Rules

| ✅ Do | ❌ Don't |
|---|---|
| `.foregroundStyle(.primary)` | `.foregroundColor(.black)` |
| `.foregroundStyle(.secondary)` | `.foregroundColor(.gray)` |
| `.tint(.blue)` untuk interactive | Hardcode `Color(hex: "#007AFF")` |
| Asset Catalog untuk brand color dengan Light/Dark variants | Inline `Color(red:green:blue:)` |
| Remove custom `toolbarBackground` in iOS 26 | Override toolbar di iOS 26 |

---

## 4. Liquid Glass — iOS 26 Material System

> **WWDC25**: "Liquid Glass unifies Apple platform design language while providing a more dynamic and expressive user experience." — Meet Liquid Glass, WWDC25

### 4.1 Apa Itu Liquid Glass

Liquid Glass adalah **digital meta-material** yang:
- Menggabungkan blur, refraction (pembiasan cahaya), dan reflection
- Dynamically bends and shapes light (bukan scatter seperti material sebelumnya)
- Reacts to touch in real time (interactive state dengan specular highlights)
- Otomatis adapts antara light dan dark context berdasarkan konten di bawahnya
- BUKAN glassmorphism biasa — ini adalah functional layer, bukan dekorasi

**Inspirasi evolution**: Aqua (Mac OS X) → iOS 7 blurs → iPhone X fluidity → Dynamic Island → visionOS → Liquid Glass

### 4.2 Dua Layer Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  MATERIAL LAYER (Liquid Glass)                              │
│  Navigation bars, toolbars, tab bars, FABs, controls       │
│  Translucent, refracts/reflects content beneath it         │
│  Otomatis switches light ↔ dark sesuai content underneath  │
├─────────────────────────────────────────────────────────────┤
│  CONTENT LAYER (App content)                                │
│  Lists, forms, text, images, camera previews               │
│  Solid/opaque backgrounds — menjadi "world" yang terlihat  │
│  melalui material layer di atasnya                          │
└─────────────────────────────────────────────────────────────┘
```

**Prinsip penting**: Jangan campurkan glass dan content. Glass ada di navigation layer. Content ada di content layer. Aplikasi yang menaruh glass di content layer terasa busy dan tidak HIG-compliant.

### 4.3 Auto-Adoption — Yang GRATIS

Jika kamu build dengan Xcode 26 SDK, komponen ini **otomatis** mendapat Liquid Glass tanpa code changes:

| Komponen | Auto Glass Behavior |
|---|---|
| `NavigationStack` nav bar | Glass saat scroll |
| `.toolbar { }` | Glass background otomatis |
| `TabView` tab bar | Glass, compact form factor |
| `Sheet` presentation | Rounded, glass-edged |
| `Toggle` | Glass knob saat interaction |
| `Slider` | Glass scrubber saat interaction |
| `Stepper` | Refreshed glass appearance |
| `Picker(.segmented)` | Glass segments saat selection |
| `Picker(.menu)` | Glass popover |
| `Button` (standard) | Glass on tap interaction |
| `.searchable` search bar | Glass treatment |

### 4.4 Manual Glass — `glassEffect(_:in:)` Modifier

Gunakan **hanya** untuk custom floating elements yang bukan standard system component:

```swift
// Basic glass effect — default shape: Capsule
Text("Hello, World!")
    .font(.title)
    .padding()
    .glassEffect()

// Custom shape: RoundedRectangle
Text("Hello, World!")
    .font(.title)
    .padding()
    .glassEffect(in: .rect(cornerRadius: 16.0))

// Tinted + interactive (untuk floating action buttons, custom controls)
Button("Action") { action() }
    .padding()
    .glassEffect(.regular.tint(.orange).interactive())

// ⚠️ PENTING: .glassEffect() SELALU di modifier terakhir
// ✅ Correct
Button("Plus") { }
    .font(.headline)
    .padding()
    .glassEffect(.regular.interactive())

// ❌ Wrong — padding setelah glass = glass di dalam padding box
Button("Plus") { }
    .glassEffect(.regular.interactive())
    .padding()
```

### 4.5 Glass Styles

| Style | Deskripsi | Kapan Pakai |
|---|---|---|
| `.regular` | Frosted glass — standard thickness | Floating buttons, custom pills |
| `.clear` | Minimal, almost transparent | Very subtle glass hint |
| `.identity` | **No effect** — passes through visually | Conditional logic: toggle glass on/off |
| `.regular.interactive()` | Responds to touch dengan real-time highlight | Custom interactive elements |
| `.clear.interactive()` | Minimal interactive | Subtle interactive custom elements |
| `.regular.tint(color)` | Colored glass tint | Suggest prominence/category |

```swift
// .identity: useful untuk conditional glass
Text("Label")
    .padding()
    .glassEffect(isActive ? .regular : .identity)   // toggle tanpa layout shift
```

### 4.6 Button Styles — Glass Variants (BARU iOS 26)

```swift
// Standard glass button — translucent, default appearance
Button("Add") { }
    .buttonStyle(.glass)

// Prominent glass button — filled/high-emphasis (seperti "primary action")
Button("Save") { }
    .buttonStyle(.glassProminent)
    .tint(.accentColor)

// Gunakan di WishlistView (Apple official sample):
Button {
    isPresentingAddTrip = true
} label: {
    Image(systemName: "plus")
}
.buttonStyle(.glassProminent)
.tint(.accentColor)

// Tinted glass buttons
Button("Warning") { }
    .buttonStyle(.glass)
    .tint(.orange)
```

**Glass Button Styles vs `.glassEffect()`:**
- `.buttonStyle(.glass)` / `.buttonStyle(.glassProminent)` → untuk `Button` views, handles all interaction states
- `.glassEffect(.regular.interactive())` → untuk non-Button views yang perlu glass appearance

### 4.7 New Button Roles (iOS 26)

```swift
// Confirm role — checkmark icon, confirm action styling
Button(role: .confirm) {
    saveAction()
}
// Renders sebagai checkmark button di toolbar — GRATIS styling

// Close role — xmark icon, dismiss styling
// ⚠️ SEMANTICS: .close adalah untuk menutup INFORMATIONAL/READ-ONLY content
// Untuk form dengan perubahan yang bisa di-discard → gunakan .cancel
Button(role: .close) {
    dismiss()
}
// Renders sebagai X button — GRATIS styling

// Destructive (existing)
Button("Delete", role: .destructive) { deleteAction() }

// Cancel (existing) — untuk membatalkan operasi yang sedang berjalan
Button("Cancel", role: .cancel) { cancelAction() }
```

**Kapan pakai `.close` vs `.cancel`:**
| Situasi | Role | Alasan |
|---|---|---|
| Menutup informational sheet (tidak ada data loss) | `.close` | Hanya "selesai melihat" |
| Menutup form yang belum ada perubahan | `.close` | Tidak ada data yang terbuang |
| Membatalkan form yang sudah ada perubahan | `.cancel` | Ada data yang akan dibuang |
| Menghentikan operasi yang sedang berjalan | `.cancel` | Hentikan proses |

**Contoh dari Wishlist app (Apple official — menggunakan `.close` untuk form):**
```swift
// Apple menggunakan .close bahkan untuk form dengan changes
// karena ada confirmationDialog sebagai safety net
ToolbarItem(placement: .navigation) {
    Button(role: .close) {           // Automatic X icon
        if model.hasChanges {
            isDiscardConfirmationShowing = true  // Safety net
        } else {
            isPresented = false
        }
    }
}

ToolbarItem(placement: .primaryAction) {
    if model.isEditing {
        Button(role: .confirm) {      // Automatic checkmark icon
            model.isEditing.toggle()
        }
    } else {
        Button("Edit") {
            model.isEditing.toggle()
        }
    }
}
```

### 4.8 GlassEffectContainer — Performance & Morphing

```swift
// Tanpa container: setiap glass element di-render terpisah (lebih berat)
HStack {
    Button("A") { }.glassEffect(.regular.interactive())
    Button("B") { }.glassEffect(.regular.interactive())
}

// Dengan container: single render pass + shape morphing
GlassEffectContainer(spacing: 8) {
    HStack {
        Button("A") { }.glassEffect(.regular.interactive())
        Button("B") { }.glassEffect(.regular.interactive())
    }
}
```

**`spacing` parameter di `GlassEffectContainer`:**
- Controls kapan shapes mulai merge saat proximity
- Larger spacing → lebih cepat merge (shape menyatu sebelum benar-benar bertemu)
- Lebih kecil dari spacing `HStack` interior → shapes tidak merge

### 4.9 glassEffectID Morphing

Ketika views di dalam `GlassEffectContainer` share matching IDs dan ditambah/dihapus dengan `withAnimation`, glass shapes akan morph secara fluid:

```swift
GlassEffectContainer {
    HStack {
        if showExpanded {
            Button("Cancel") { }
                .glassEffect(.regular.interactive())
                .glassEffectID("left", in: containerNamespace)
        }

        Button("Confirm") { }
            .glassEffect(.regular.interactive())
            .glassEffectID("right", in: containerNamespace)
    }
}
// withAnimation { showExpanded.toggle() }
// → Glass shapes morph into/out of each other dengan fluid animation
```

### 4.10 Adopting Liquid Glass — Checklist

```
□ Remove custom toolbarBackground/toolbarColorScheme (let system handle it)
□ Remove custom navigation bar appearances (UINavigationBarAppearance)
□ Check tab bar customizations — remove custom backgrounds
□ Test Reduce Transparency: system auto-provides solid fallback
□ Test Increase Contrast: glass tinting remains accessible
□ Legibility: teks terbaca di atas background yang bergerak/colorful
□ .glassEffect() adalah modifier terakhir di chain
□ Multiple glass elements → wrap dalam GlassEffectContainer
□ Custom floating elements gunakan .glassEffect(.regular.interactive())
```

### 4.11 Opt-Out (Compatibility Mode)

Jika butuh tampilan iOS 18 di iOS 26:
```
// Info.plist
UIDesignRequiresCompatibility = YES
```
Ini akan merender UI seperti iOS 18 dan sebelumnya. **Tidak direkomendasikan** untuk app baru.

### 4.12 Rules — Yang HARUS dan TIDAK BOLEH

| ✅ Do | ❌ Don't |
|---|---|
| Biarkan system components auto-apply Glass | Tambah `.glassEffect()` ke `NavigationStack` / `List` |
| Gunakan `.buttonStyle(.glassProminent)` untuk primary action | Gunakan glass untuk list rows atau form sections |
| Wrap multiple glass elements dalam `GlassEffectContainer` | Multiple glass elements tanpa container |
| `.glassEffect()` sebagai modifier **terakhir** | Modifier setelah `.glassEffect()` |
| Remove custom `toolbarBackground` | Override toolbar color di iOS 26 |
| `.scrollEdgeEffectStyle` untuk edge context | `toolbarBackground(.visible)` untuk opacity control |
| Test di Reduce Transparency | Andalkan glass untuk contrast |

---

## 5. SF Symbols 7

> **Versi terbaru untuk iOS 26**: SF Symbols **7** — bukan 6. SF Symbols 6 adalah versi untuk iOS 18.

### 5.1 Prinsip Dasar

SF Symbols 7 menyediakan **6,900+ ikon** yang dirancang match dengan San Francisco. Gunakan SELALU sebelum mempertimbangkan custom assets.

### 5.2 Rendering Modes

| Mode | Deskripsi | Kapan Pakai |
|---|---|---|
| **Monochrome** | Satu warna untuk semua layer | Default, most cases |
| **Hierarchical** | Satu warna, opacity bervariasi per layer | Depth emphasis (speaker.wave) |
| **Palette** | 2-3 warna custom per layer | Custom branded icons |
| **Multicolor** | Warna intrinsic Apple | Weather, signal, system status |

```swift
Image(systemName: "sparkles")                           // Monochrome (default)

Image(systemName: "sparkles")
    .symbolRenderingMode(.hierarchical)                 // Hierarchical

Image(systemName: "sparkles")
    .symbolRenderingMode(.palette)
    .foregroundStyle(.blue, .cyan)                      // Palette

Image(systemName: "photo.circle")
    .symbolRenderingMode(.multicolor)                   // Multicolor
    .symbolVariant(.fill)                               // Use fill variant
```

### 5.3 Animation — SF Symbols 7

```swift
Image(systemName: "checkmark.circle.fill")
    .symbolEffect(.bounce, value: triggerValue)             // Bounce on action

Image(systemName: "arrow.triangle.2.circlepath")
    .symbolEffect(.pulse)                                   // Continuous pulse

Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
    .contentTransition(.symbolEffect(.replace))             // Magic Replace

Image(systemName: "wifi", variableValue: signalStrength)    // Variable value (0.0–1.0)

// 🆕 SF Symbols 7 — Draw animations (BARU iOS 26)
Image(systemName: "arrow.right")
    .symbolEffect(.draw)                                    // Draw On (whole symbol)

Image(systemName: "checkmark")
    .symbolEffect(.draw.byLayer)                            // Draw On by layer

Image(systemName: "sparkles")
    .symbolEffect(.draw.individually)                       // Draw On one layer at a time

// 🆕 SF Symbols 7 — Gradients (BARU iOS 26)
Image(systemName: "star.fill")
    .symbolRenderingMode(.hierarchical)                     // Gradient auto-generated from tint
    .foregroundStyle(.orange)
```

**SF Symbols 7 New Features Summary:**
| Feature | API | iOS |
|---|---|---|
| Draw On animation | `.symbolEffect(.draw)` | 26+ |
| Draw Off animation | `.symbolEffect(.draw.off)` | 26+ |
| Draw by layer | `.symbolEffect(.draw.byLayer)` | 26+ |
| Variable Draw | `variableValue:` + draw support | 26+ |
| Gradients | Auto with `.hierarchical` mode | 26+ |
| Enhanced Magic Replace | Preserves enclosure shapes | 26+ |

### 5.4 Common Symbols untuk Photography App

| Fungsi | Symbol | Alternative |
|---|---|---|
| Camera | `camera.fill` | `camera` |
| Capture | `camera.shutter.button` | `circle.fill` (large) |
| Gallery | `photo.stack` | `photo.on.rectangle` |
| Composition grid | `grid` | `square.grid.3x3` |
| Golden ratio | `aspectratio` | `squareshape.dashed.squareshape` |
| Horizon level | `level` | `lines.measurement.horizontal` |
| Face detection | `face.dashed` | `person.crop.rectangle` |
| AI / ML | `sparkles` | `wand.and.stars` |
| Score | `star.fill` | `gauge.high` |
| Toggle overlay | `square.grid.3x3` | `grid.circle` |
| Save photo | `square.and.arrow.down` | `photo.badge.checkmark` |
| Settings | `gearshape.fill` | `slider.horizontal.3` |
| Flash | `bolt.fill` | `bolt.slash.fill` |
| Flip camera | `camera.rotate.fill` | `arrow.triangle.2.circlepath` |
| Landscape | `mountain.2.fill` | `photo.fill` |
| Portrait | `person.fill` | `person.crop.rectangle.fill` |

### 5.5 Rules

| ✅ Do | ❌ Don't |
|---|---|
| Cari di SF Symbols app dulu | Custom SVG sebelum cek SF Symbols |
| Gunakan `.font()` yang sama dengan teks yang bersebelahan | Hardcode `.frame(width:height:)` untuk ikon |
| `.symbolVariant(.fill)` untuk emphasis | Mix filled dan unfilled dalam satu layer |
| Test di Monochrome dulu | Start dengan Multicolor |
| Keep animations subtle dan purposeful | Animasi untuk dekorasi |

---

## 6. Layout & Spacing

### 6.1 8-Point Grid

```
4pt  — Micro gap (between icon and label in HStack)
8pt  — Small gap (between elements in a row)
12pt — Medium gap (between sections within a card)
16pt — Standard margin (horizontal padding) ← DEFAULT
20pt — Section gap
24pt — Large separation
32pt — Major section break
```

### 6.2 Safe Area

```swift
// ✅ Respect safe area (default behavior)
List { ... }
ScrollView { ... }

// ✅ Full-bleed image dengan content dalam safe area
ScrollView {
    VStack {
        HeroImage()
            .ignoresSafeArea(edges: .top)   // Image extends under nav bar
        content
    }
}

// ✅ Camera app: full screen ignoresSafeArea
ZStack {
    CameraPreview()
        .ignoresSafeArea()         // Full-screen camera
    OverlayControls()              // Overlay respects safe area via padding
}
```

### 6.3 contentMargins — BARU iOS 17+ (dipakai iOS 26)

```swift
// Tambah margin pada scroll content tanpa mempengaruhi safe area
ScrollView {
    content
}
.contentMargins(.bottom, 30, for: .scrollContent)  // Extra space di bawah last item

// Konteks: .scrollContent, .scrollIndicators, .all
.contentMargins(16, for: .scrollContent)           // Semua sisi
.contentMargins(.horizontal, 16, for: .scrollContent)
```

**Contoh dari Wishlist app:**
```swift
ScrollView { ... }
    .contentMargins(.bottom, 30, for: .scrollContent)
    // → Mencegah last item tertutup tab bar + tambah breathing room
```

### 6.4 containerRelativeFrame — BARU iOS 17+

```swift
// Frame relatif terhadap container (bukan screen)
TripImageView()
    .containerRelativeFrame(.horizontal)    // Full width of containing scroll

// Dengan multiplier closure
.containerRelativeFrame([.horizontal, .vertical]) { length, axis in
    if axis == .vertical {
        return length / 1.3              // 76.9% of container height
    } else {
        return length                    // Full width
    }
}
```

### 6.5 Touch Targets

```swift
// Minimum 44×44pt
Button("Action") { ... }   // Already ≥ 44pt tall in List/Form

// Custom small element — expand touch area
Image(systemName: "camera")
    .frame(minWidth: 44, minHeight: 44)
    .contentShape(Rectangle())
```

---

## 7. Navigation Patterns — iOS 26 Updated

### 7.1 NavigationStack — Wajib di iOS 26

```swift
// Standard pattern
NavigationStack {
    List { ... }
        .navigationTitle("Title")
        .toolbarTitleDisplayMode(.inline)    // iOS 26 style: title in toolbar row
        .toolbarRole(.editor)                // Leading-align title
}
```

### 7.2 NavigationTransition — Zoom (BARU iOS 18+)

Zoom transition adalah **navigation transition resmi Apple iOS 26** — digunakan di Wishlist app, Landmarks app, dan semua official samples:

```swift
struct ContentView: View {
    @Namespace private var namespace

    var body: some View {
        NavigationStack {
            List(items) { item in
                NavigationLink {
                    DetailView(item: item)
                        .navigationTransition(            // ← Destination
                            .zoom(sourceID: item.id, in: namespace))
                } label: {
                    ItemCard(item: item)
                        .matchedTransitionSource(          // ← Source
                            id: item.id, in: namespace)
                }
            }
        }
    }
}
```

**`matchedTransitionSource` configuration:**
```swift
// Basic
.matchedTransitionSource(id: item.id, in: namespace)

// With corner radius interpolation
.matchedTransitionSource(id: item.id, in: namespace) { source in
    source.cornerRadius(8.0)   // Smoothly interpolated during transition
}
```

### 7.3 navigationSubtitle (BARU iOS 26)

```swift
NavigationStack {
    ContentView()
        .navigationTitle("Landmarks")         // Primary title
        .navigationSubtitle("25 places")      // 🆕 Secondary info below title
}
// → Menampilkan subtitle di bawah navigation title
// → Saat scroll: subtitle muncul otomatis dengan ToolbarItem(placement: .subtitle)
```

### 7.4 NavigationSplitView — iOS 26 Sidebar Glass

```swift
NavigationSplitView {
    SidebarContent()
        // Sidebar otomatis mendapat glass appearance
} detail: {
    ZStack {
        HeroImage()
            .backgroundExtensionEffect()  // Extends under sidebar
        DetailContent()
    }
}
```

### 7.5 backgroundExtensionEffect (BARU iOS 26)

Membuat view "extend" ke luar batasnya secara mirrored + blurred:

```swift
// Use case: Image extends under sidebar/inspector
Image("hero")
    .resizable()
    .backgroundExtensionEffect()  // Mirror-blurs under sidebar

// Common pattern: full-bleed immersive header
ScrollView {
    VStack {
        TripImageView(url: model.photoURL)
            .containerRelativeFrame(.horizontal)
            .frame(height: 510)
            .clipped()
        // ↑ Image di atas; .backgroundExtensionEffect() di context NavigationSplitView
    }
}
.ignoresSafeArea(edges: .top)
```

**Rules:**
- Gunakan hanya untuk SATU instance background content per view
- Jangan apply ke content yang ada di atas background (overlay text, buttons)
- Paling berguna di NavigationSplitView detail column

---

## 8. Toolbar APIs — iOS 26 Complete Guide

### 8.1 New iOS 26 Toolbar Pattern

iOS 26 mengubah cara toolbar bekerja secara fundamental. Title dan action buttons sekarang **berada di baris yang sama** (bukan di atas sendiri).

> **⚠️ Klarifikasi `toolbarRole(.editor)`**: Berdasarkan dokumentasi resmi, `.browser` leading-aligns title di iPadOS. Namun `.editor` + `.toolbarTitleDisplayMode(.inline)` + `ToolbarItem(placement: .title)` adalah pola yang digunakan Apple di Wishlist app (official sample) untuk mendapatkan leading-aligned title di iOS 26. Pola ini terbukti bekerja di iPhone dan iPad.

```swift
NavigationStack {
    List { ... }
        .navigationTitle("Title")          // Accessibility label only
        .toolbarTitleDisplayMode(.inline)  // Title di baris toolbar
        .toolbarRole(.editor)              // Leading-align the title
        .toolbar {
            // Custom title dengan font kustom
            ToolbarItem(placement: .title) {
                ExpandedNavigationTitle(title: "Wishlist")
            }

            // Action buttons (trailing)
            ToolbarItem(placement: .topBarTrailing) {
                Button { isPresentingAdd = true } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.glassProminent)
                .tint(.accentColor)
            }
        }
}
```

### 8.2 ToolbarItem Placements — Complete List

| Placement | Posisi | iOS | Gunakan untuk |
|---|---|---|---|
| `.title` | Title area (inline) | 26+ 🆕 | Custom title view saat inline mode |
| `.largeTitle` | Large title area (out-of-line) | 26+ 🆕 | Custom title saat title rendered full-size |
| `.subtitle` | Subtitle (inline) | 26+ 🆕 | Subtitle saat di-scroll ke atas |
| `.largeSubtitle` | Large subtitle | 26+ 🆕 | Subtitle saat large title visible |
| `.topBarLeading` | Nav bar kiri | 16+ | Back button companion, close |
| `.topBarTrailing` | Nav bar kanan | 16+ | Primary action, edit |
| `.navigation` | Navigation area | 16+ | Close/back di modal |
| `.primaryAction` | Primary action slot | 14+ | Confirm/save action |
| `.confirmationAction` | Confirmation slot | 14+ | Modal sheet confirm (legacy; prefer `Button(role: .confirm)`) |
| `.cancellationAction` | Cancellation slot | 14+ | Modal sheet cancel (legacy; prefer `Button(role: .close/.cancel)`) |
| `.principal` | Center of toolbar | 14+ | Custom center view (iOS 14, sebelum `.title`) |
| `.bottomBar` | Bottom toolbar | 14+ | Secondary actions |
| `.status` | Status bar area | 14+ | Status text |

> **Note**: `.title` dan `.largeTitle` menggantikan/melengkapi `.principal`. Gunakan `.title` ketika `toolbarTitleDisplayMode(.inline)` aktif.

### 8.3 toolbarTitleDisplayMode — All Options

| Mode | Behavior | Kapan Pakai |
|---|---|---|
| `.automatic` | Default — large title untuk root, inline untuk pushed | Standard navigation |
| `.large` | Large title (scrolls away) | Root screens dengan lots of content |
| `.inline` | Compact inline title | Modals, pushed detail views, iOS 26 style screens |
| `.inlineLarge` | Large title in same row as toolbar buttons | iOS 26 new style — title + buttons side by side |

**iOS 26 recommended pattern:**
```swift
// Root screen dengan custom title
.toolbarTitleDisplayMode(.inline)
.toolbarRole(.editor)
// + ToolbarItem(placement: .title) { customTitleView }

// atau: built-in large title in toolbar row
.toolbarTitleDisplayMode(.inlineLarge)
// Hasilnya: title dan toolbar buttons berbagi baris yang sama
```

### 8.4 toolbarRole

| Role | Behavior |
|---|---|
| `.automatic` | Default |
| `.editor` | **Leading-aligns** the title — title tidak center, tapi left-aligned |
| `.navigationStack` | NavigationStack root behavior |
| `.browser` | Browser-style (macOS) |

```swift
// Digunakan di SEMUA screens di Wishlist app:
.toolbarTitleDisplayMode(.inline)
.toolbarRole(.editor)
// → Title left-aligned, buttons right — iOS 26 standard layout
```

### 8.5 ToolbarSpacer (BARU iOS 26)

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        Button("Edit") { }
    }
    ToolbarSpacer(.fixed(20), placement: .topBarTrailing)  // Fixed gap
    ToolbarItem(placement: .topBarTrailing) {
        Button("Share") { }
    }
}
```

### 8.6 Toolbar Shared Background Visibility (BARU iOS 26)

```swift
// Control visibility of glass background on specific toolbar items
ToolbarItem(placement: .topBarTrailing) {
    Button("Action") { }
        .toolbarItemGroupSharedBackgroundVisibility(.hidden)  // Remove glass bubble
}
```

### 8.7 Rules — Toolbar iOS 26

| ✅ Do | ❌ Don't |
|---|---|
| `.toolbarTitleDisplayMode(.inline)` + `.toolbarRole(.editor)` | `.navigationBarTitleDisplayMode(.large)` di iOS 26 (jika mau new style) |
| `Button(role: .confirm)` untuk save | `.confirmationAction` placement dengan text "Save" |
| `Button(role: .close)` untuk dismiss | `.cancellationAction` placement dengan text "Cancel" |
| `.buttonStyle(.glassProminent)` untuk primary toolbar button | Custom background pada toolbar buttons |
| `ToolbarItem(placement: .title)` untuk custom title | `.navigationBarTitle()` (deprecated pattern) |
| Test dengan Dynamic Type — title harus truncate gracefully | Assume title selalu fit in one line |

---

## 9. Scroll APIs — iOS 26 Updated

### 9.1 scrollEdgeEffectStyle (BARU iOS 26)

Menggantikan `toolbarBackground(.visible)` sebagai cara mengkomunikasikan batas antara toolbar dan konten:

```swift
ScrollView {
    content
}
.scrollEdgeEffectStyle(.soft, for: .top)    // Soft gradient fade — default iOS 26
.scrollEdgeEffectStyle(.hard, for: .top)    // Hard dividing line (mirip iOS 18 solid bar)
.scrollEdgeEffectStyle(.none, for: .top)    // No effect

// Untuk kamera app dengan full-screen scroll:
.scrollEdgeEffectStyle(.none, for: .top)    // Camera tidak butuh top edge effect
```

**Dari Wishlist app:**
```swift
ScrollView(.vertical) {
    VStack { ... }
}
.scrollEdgeEffectStyle(.soft, for: .top)   // Smooth fade masuk konten
```

### 9.2 scrollTransition — Interactive Parallax (iOS 17+)

```swift
// Interactive scroll effect: elemen bereaksi terhadap scroll position
ScrollView(.horizontal) {
    LazyHStack {
        ForEach(items) { item in
            ItemView(item: item)
                .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                    content
                        .scaleEffect(1.0 - 0.12 * abs(phase.value))     // Shrink ketika di pinggir
                        .rotation3DEffect(
                            Angle(degrees: 20 * phase.value),            // Flip efek 3D
                            axis: (0, 1, 0))
                }
        }
    }
    .scrollTargetLayout()
}
.scrollTargetBehavior(.viewAligned)
.scrollClipDisabled()                                                     // Allow overflow visible
```

`phase.value`: −1.0 (leading edge) → 0.0 (identity/centered) → 1.0 (trailing edge)

### 9.3 Scroll Configuration Patterns

```swift
ScrollView(.horizontal) {
    LazyHStack(spacing: 12) {
        ForEach(items) { item in
            ItemCard()
                .frame(width: 180)
        }
    }
    .scrollTargetLayout()              // Tell system which views are targets
}
.scrollTargetBehavior(.viewAligned)    // Snap to view boundaries
.scrollClipDisabled()                  // Content dapat terlihat di luar scroll frame
.scrollIndicators(.hidden, axes: .horizontal)  // Hide horizontal scrollbar
.safeAreaPadding(40)                   // Add breathing room
```

### 9.4 contentMargins vs padding

```swift
// padding: affects layout
// contentMargins: affects scroll behavior + insets

ScrollView {
    LazyVStack { content }
}
.contentMargins(.bottom, 30, for: .scrollContent)
// → Last item memiliki 30pt extra space sebelum menyentuh batas scroll
// → Tidak mempengaruhi layout dari content itu sendiri

// Berbeda dari:
LazyVStack {
    content
    Spacer().frame(height: 30)   // Kurang ideal — adds spacer to content
}
```

### 9.5 scrollDismissesKeyboard

```swift
// Dismiss keyboard immediately when scroll starts
.scrollDismissesKeyboard(.immediately)

// Interactively — keyboard tracks dengan scroll
.scrollDismissesKeyboard(.interactively)

// Never dismiss
.scrollDismissesKeyboard(.never)
```

---

## 10. TabView — iOS 26 Updated

### 10.1 Tab-Bar Auto-Updates

Di iOS 26, `TabView` otomatis mendapat:
- Compact form factor (lebih kecil dari iOS 18)
- Liquid Glass background
- Hapus custom `tabBarAppearance` — akan bertentangan dengan Glass

### 10.2 sidebarAdaptable (BARU)

```swift
TabView {
    Tab("Home", systemImage: "house.fill") {
        HomeView()
    }
    Tab("Search", systemImage: "magnifyingglass") {
        SearchView()
    }
    Tab("Profile", systemImage: "person.fill") {
        ProfileView()
    }
}
.tabViewStyle(.sidebarAdaptable)   // Tab bar on iPhone, sidebar on iPad
```

### 10.3 tabBarMinimizeBehavior (BARU)

```swift
TabView { ... }
    .tabBarMinimizeBehavior(.onScrollDown)  // Tab bar hides when scrolling down
    // → Lebih banyak ruang untuk content
    // → Tab bar muncul kembali saat scroll ke atas
```

### 10.4 Tab Roles (BARU)

```swift
TabView {
    Tab("Wishlist", systemImage: "heart.fill") {
        WishlistView()
    }
    Tab("Goals", systemImage: "trophy.fill") {
        GoalsView()
    }
    Tab(role: .search) {       // Built-in search tab with searchable integration
        SearchView()
    }
}
```

### 10.5 Bottom Accessory (BARU)

```swift
TabView {
    Tab("Home", systemImage: "house.fill") {
        HomeView()
            .tabViewBottomAccessory {        // Content above tab bar
                NowPlayingBar()
            }
    }
}
```

---

## 11. Lists & Forms

### 11.1 List Styles

| Style | SwiftUI | Gunakan untuk |
|---|---|---|
| **Inset Grouped** | `.listStyle(.insetGrouped)` | Default untuk iOS. Rounded corners, padded. |
| **Grouped** | `.listStyle(.grouped)` | Edge-to-edge rows, grouped sections |
| **Plain** | `.listStyle(.plain)` | Minimal, full-width. Untuk search results. |
| **Sidebar** | `.listStyle(.sidebar)` | iPad sidebar navigation |

### 11.2 Section Index Label (BARU iOS 26)

```swift
List {
    ForEach(groupedItems) { group in
        Section {
            ForEach(group.items) { item in
                ItemRow(item: item)
            }
        } header: {
            Text(group.letter)
        }
        .sectionIndexLabel(Text(group.letter))   // Single char shown in index
    }
}
.listSectionIndexVisibility(.always)             // Always show section index
```

### 11.3 Section Margins (BARU iOS 26)

```swift
List { ... }
    .listSectionSpacing(20)                       // Standard section spacing
    .listSectionSpacing(.compact)                 // Compact spacing
```

### 11.4 Form Components

| Component | SwiftUI | Gunakan untuk |
|---|---|---|
| **Text input** | `TextField` | Nama, nomor, single-line input |
| **Multiline text** | `TextEditor` / `TextField(axis: .vertical)` | Catatan, notes |
| **Rich text** (BARU) | `TextEditor` dengan `AttributedString` | Formatted text |
| **Date/Time** | `DatePicker` | Deadline |
| **Segmented** | `Picker(.segmented)` | 2-5 opsi mutual exclusive |
| **Menu picker** | `Picker(.menu)` | Banyak opsi |
| **Stepper** | `Stepper` | Angka integer |
| **Toggle** | `Toggle` | Boolean on/off |
| **Labeled** | `LabeledContent` | Label-value pairs |

### 11.5 When to Use What Picker

| Jumlah Opsi | Component |
|---|---|
| 2-5 | `Picker(.segmented)` |
| 6-12 | `Picker(.menu)` |
| 13+ | `Picker(.navigationLink)` |
| Boolean | `Toggle` |
| Integer range | `Stepper` |
| Date/Time | `DatePicker` |

---

## 12. Sheets & Modals

### 12.1 Standard Sheet Pattern

```swift
.sheet(isPresented: $showForm) {
    NavigationStack {
        FormView()
            .navigationTitle("New Item")
            .navigationBarTitleDisplayMode(.inline)   // WAJIB inline di modal
            .toolbar {
                ToolbarItem(placement: .navigation) {  // iOS 26: pakai .navigation bukan .cancellationAction
                    Button(role: .close) {             // iOS 26: role: .close auto-styles
                        if model.hasChanges {
                            showDiscardConfirmation = true
                        } else {
                            showForm = false
                        }
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(role: .confirm) {           // iOS 26: role: .confirm auto-styles
                        save()
                    }
                    .disabled(!model.canSave)
                }
            }
            .interactiveDismissDisabled(model.hasChanges)  // Prevent accidental dismiss
    }
}
```

### 12.2 Discard Confirmation Pattern

```swift
// Dari Wishlist app — HIG-compliant pattern untuk prevent data loss
ToolbarItem(placement: .navigation) {
    Button(role: .close) {
        if model.hasChanges {
            isDiscardConfirmationShowing = true
        } else {
            isPresented = false
        }
    }
    .confirmationDialog("Discard changes?", isPresented: $isDiscardConfirmationShowing) {
        Button(role: .destructive) {
            isPresented = false
        } label: {
            Text("Discard")
        }
        // Cancel is automatic
    }
}
```

### 12.3 Zoom Transition dari Modal Source

```swift
// Button → Modal dengan zoom transition
Button {
    isPresentingAdd = true
} label: {
    Image(systemName: "plus")
}
.matchedTransitionSource(id: "addTrip", in: namespace)  // Sumber zoom
.buttonStyle(.glassProminent)

.sheet(isPresented: $isPresentingAdd) {
    AddView()
        .navigationTransition(
            .zoom(sourceID: "addTrip", in: namespace))  // Zoom masuk dari button
}
```

### 12.4 Destructive Actions

```swift
// ✅ confirmationDialog — HIG compliant untuk destructive
.confirmationDialog(
    "Hapus Foto?",
    isPresented: $showDelete,
    titleVisibility: .visible
) {
    Button("Hapus", role: .destructive) { deleteAction() }
    Button("Batal", role: .cancel) { }
} message: {
    Text("Foto akan dihapus permanen.")
}
```

---

## 13. Empty States

### 13.1 ContentUnavailableView

```swift
// No content at all
ContentUnavailableView(
    "No Photos Yet",
    systemImage: "camera",
    description: Text("Open the camera to start capturing.")
)

// No search results (auto-localized)
ContentUnavailableView.search(text: searchText)

// Custom with action button
ContentUnavailableView {
    Label("Tidak Ada Koneksi", systemImage: "wifi.slash")
} description: {
    Text("Cek koneksi internet Anda.")
} actions: {
    Button("Coba Lagi") { retry() }
        .buttonStyle(.glass)    // iOS 26: glass style untuk action button
}
```

### 13.2 Rules

| ✅ Do | ❌ Don't |
|---|---|
| Gunakan `ContentUnavailableView` (iOS 17+) | Custom VStack dengan Image + Text |
| Jelaskan KENAPA kosong | Tampilkan halaman blank |
| Beri action untuk resolve | Hide navigation elements |
| `.search` untuk empty search results | Custom "no results" message |

---

## 14. Search

### 14.1 Implementation

```swift
// Standard searchable — otomatis terintegrasi dengan tab bar di iOS 26
.searchable(
    text: $searchText,
    prompt: "Trips, Destinations and More."
)
.scrollDismissesKeyboard(.immediately)  // Keyboard dismiss saat scroll

// Dari Wishlist app — .searchable pada NavigationStack content
NavigationStack {
    SearchResultsListView()
        .navigationTitle("Search")
        .toolbarTitleDisplayMode(.inline)
        .toolbarRole(.editor)
        .searchable(
            text: $dataSource.searchText,
            prompt: "Trips, Destinations and More."
        )
        .scrollDismissesKeyboard(.immediately)
}
```

### 14.2 Search Tab Integration (BARU iOS 26)

```swift
// Tab(role: .search) — search tab otomatis terintegrasi dengan .searchable
TabView {
    Tab(role: .search) {
        SearchView()
            .searchable(text: $searchText, prompt: "Search...")
    }
}
// → Tap search tab langsung fokus ke search field
```

### 14.3 Liquid Glass Integration

Di iOS 26, search field otomatis mendapat Liquid Glass treatment. **Jangan style custom** — biarkan sistem menangani visual.

---

## 15. Materials & Backgrounds

### 15.1 Material Hierarchy

Apple menyediakan system materials yang otomatis adaptif untuk Light/Dark/High Contrast:

```swift
// Materials — dari paling tipis ke paling tebal
.background(.ultraThinMaterial)     // Barely there — untuk subtle overlay
.background(.thinMaterial)          // Light frost
.background(.regularMaterial)       // Standard frosted glass
.background(.thickMaterial)         // Heavy frost
.background(.ultraThickMaterial)    // Very opaque frost

// Gunakan sebagai background modifier
Text("Label")
    .padding(4)
    .background(.regularMaterial, in: .rect(cornerRadius: 8))
    // ↑ ini pola yang digunakan di Wishlist app untuk activity count badge
```

### 15.2 Material dengan Shape

```swift
// Clean pattern dari Wishlist app:
Text("3 ACTIVITIES")
    .font(.footnote)
    .padding(4)
    .background(.regularMaterial, in: .rect(cornerRadius: 8))

// Layering: image + material background
.overlay(alignment: .bottomLeading) {
    VStack { ... }
        .background {
            GradientView(style: .ultraThinMaterial)  // Custom gradient mask + material
        }
}
```

### 15.3 MeshGradient (BARU iOS 18+)

```swift
// MeshGradient: gradient dengan kontrol lebih halus dari LinearGradient/RadialGradient
MeshGradient(
    width: 2, height: 2,
    points: [
        SIMD2<Float>(0.0, 0.0), SIMD2<Float>(1.0, 0.0),
        SIMD2<Float>(0.0, 1.0), SIMD2<Float>(1.0, 1.0)
    ],
    colors: [
        .clear, .clear,
        .black, .clear   // Gradient dari hitam (bottom-leading) ke clear
    ]
)

// Digunakan di Wishlist app sebagai gradient mask untuk material:
Rectangle()
    .fill(.ultraThinMaterial)
    .mask {
        MeshGradient(...)   // Fade effect dengan mesh gradient sebagai mask
    }
```

**Kapan pakai MeshGradient vs LinearGradient:**
- `LinearGradient` → simple fade, single direction
- `MeshGradient` → complex fade, multi-directional, corner-to-corner fade

### 15.4 Material vs Glass

| `Material` | `glassEffect()` |
|---|---|
| Digunakan sebagai background value | Digunakan sebagai view modifier |
| `.background(.regularMaterial)` | `.glassEffect(.regular)` |
| Untuk badge, card overlays, pill backgrounds | Untuk floating buttons, custom controls |
| Tidak memiliki interactive response | `.interactive()` menambah touch response |
| Stabil (tidak bergerak/morph) | Dapat morph dengan `GlassEffectContainer` |
| Available iOS 15+ | Available iOS 26+ |

---

## 16. Gestalt Theory — Applied to iOS Design

### 16.1 Proximity

Elemen yang berdekatan dipersepsi sebagai satu grup.

```swift
// ✅ Tight spacing = related
VStack(spacing: 6) {
    Text(name).font(.headline)
    Text(subtitle).font(.subheadline)
}
// Gap antara rows = 12-16pt → different group
```

### 16.2 Similarity

Elemen yang mirip dipersepsi sebagai serupa.

```swift
// ✅ Same style = same importance level
Text(item1.name).font(.headline)
Text(item2.name).font(.headline)
```

### 16.3 Symmetry & Order

```swift
HStack {
    Text(name).font(.headline)    // Left-aligned (primary)
    Spacer()
    Text(status).font(.subheadline)  // Right-aligned (metadata)
}
```

### 16.4 Figure/Ground

Di iOS 26, Liquid Glass mengelola figure/ground secara otomatis. Navigation layer (glass) = figure; content layer = ground.

### 16.5 Checklist

| Principle | Implementasi di Project |
|---|---|
| **Proximity** | Composition tip text dekat dengan area yang dirujuk |
| **Similarity** | Semua overlay guides menggunakan style yang konsisten |
| **Symmetry** | Rule of Thirds grid simetris, power points simetris |
| **Figure/Ground** | Glass overlay pada camera = figure; camera preview = ground |
| **Continuity** | Horizon line indicator mengikuti arah natural scene |

---

## 17. Design Principles Applied

### 17.1 Checklist per Screen

Setiap screen harus dievaluasi dengan 12 prinsip desain berikut:

| # | Principle | Question | Photography App View |
|---|---|---|---|
| 1 | **Content** | Apakah camera preview menjadi hero? | Camera viewfinder full-screen |
| 2 | **Balance** | Apakah overlay guides balance secara visual? | RoT grid simetris |
| 3 | **Emphasis** | Apakah subject highlight menonjol? | Saliency rect dengan warna kontras |
| 4 | **Proportion** | Apakah glass buttons proporsional dengan viewfinder? | Button 44pt minimum |
| 5 | **Unity** | Apakah semua overlays menggunakan visual language yang sama? | Semua guides berwarna putih/kuning |
| 6 | **White Space** | Apakah ada cukup breathing room di UI? | Minimal UI di atas camera |
| 7 | **Hierarchy** | Apakah score badge tidak mengalahkan tips? | Score kecil, tips lebih prominent |
| 8 | **Repetition** | Apakah power point dots konsisten ukurannya? | 4 dots di 4 intersections |
| 9 | **Rhythm** | Apakah teks tips update dengan irama yang tidak mengganggu? | Update every 1.5 seconds |
| 10 | **Pattern** | Apakah grid lines mengikuti pattern yang familiar? | RoT = familiar photography standard |
| 11 | **Movement** | Apakah horizon indicator bergerak smooth? | Spring animation, no stutter |
| 12 | **Variety** | Apakah ada variasi antara overlay types? | RoT, Golden Ratio, Diagonal — berbeda visual |

---

## 18. Quick Reference Card — iOS 26

### SwiftUI Cheat Sheet — HIG Compliant + iOS 26 Updated

```swift
// MARK: - Colors
.foregroundStyle(.primary)                      // Main text
.foregroundStyle(.secondary)                    // Supporting text
.foregroundStyle(.tertiary)                     // Placeholder
.tint(.blue)                                    // Interactive accent
Color(.systemBackground)                        // Base background
Color(.systemGroupedBackground)                 // List background

// MARK: - Typography
.font(.largeTitle)                              // 34pt Regular — screen title
.font(.title3)                                  // 20pt Semibold — section header
.font(.headline)                                // 17pt Semibold — row primary
.font(.body)                                    // 17pt Regular — form text
.font(.subheadline)                             // 15pt Regular — row secondary
.font(.caption)                                 // 12pt Regular — small metadata
.font(.caption2)                                // 11pt Regular — smallest text
.monospacedDigit()                              // Fixed-width numbers (scores, timers)
.fontWidth(.expanded)                           // 🆕 iOS 26 — wider letterforms (for titles)
.fontWidth(.condensed)                          // 🆕 iOS 26 — narrower letterforms (for labels)
.font(.footnote.smallCaps())                    // Small caps (for category labels)

// MARK: - SF Symbols 7 (iOS 26)
.symbolEffect(.draw)                            // 🆕 Draw On animation (whole symbol)
.symbolEffect(.draw.byLayer)                    // 🆕 Draw On by layer
.symbolEffect(.draw.off)                        // 🆕 Draw Off animation
.contentTransition(.symbolEffect(.replace))     // Magic Replace (existing)
.symbolRenderingMode(.hierarchical)             // Gradient rendering (auto from tint)

// MARK: - Liquid Glass (iOS 26)
.buttonStyle(.glass)                            // 🆕 Standard glass button
.buttonStyle(.glassProminent)                   // 🆕 Filled glass button (primary action)
.glassEffect()                                  // 🆕 Custom glass (capsule shape, last modifier!)
.glassEffect(in: .rect(cornerRadius: 16))       // 🆕 Custom shape glass
.glassEffect(.regular.tint(.blue).interactive()) // 🆕 Tinted interactive glass
GlassEffectContainer { ... }                    // 🆕 Container for multiple glass elements
Button(role: .confirm) { }                      // 🆕 Confirm action (checkmark icon auto)
Button(role: .close) { }                        // 🆕 Close/dismiss (X icon auto) — informational
Button(role: .cancel) { }                       // Cancel — untuk form dengan potential data loss
.glassEffect(.identity)                         // 🆕 No-op glass (untuk conditional toggle)

// MARK: - Navigation (iOS 26)
NavigationStack { }                             // Root navigator
.navigationTitle("Title")                       // Accessibility label (always set)
.toolbarTitleDisplayMode(.inline)               // 🆕 Title in toolbar row (iOS 26 style)
.toolbarTitleDisplayMode(.inlineLarge)          // 🆕 Large title in same row as buttons
.toolbarRole(.editor)                           // 🆕 Leading-align title
ToolbarItem(placement: .title) { }              // 🆕 Custom view in title area (inline)
ToolbarItem(placement: .largeTitle) { }         // 🆕 Custom view in title area (out-of-line)
ToolbarItem(placement: .subtitle) { }           // 🆕 Subtitle (shown on scroll)
ToolbarItem(placement: .largeSubtitle) { }      // 🆕 Subtitle (large title visible)
ToolbarItem(placement: .navigation) { }         // Back/close companion
ToolbarSpacer(.fixed(16), placement: .topBarTrailing)  // 🆕 Spacer in toolbar
.navigationSubtitle("25 items")                 // 🆕 Secondary title info
.navigationTransition(.zoom(sourceID: id, in: ns))     // 🆕 Zoom nav transition
.matchedTransitionSource(id: id, in: ns)        // 🆕 Source for zoom transition
.backgroundExtensionEffect()                    // 🆕 Extend bg under sidebar/inspector

// MARK: - Scroll (iOS 26)
.scrollEdgeEffectStyle(.soft, for: .top)        // 🆕 Soft edge effect at top
.scrollEdgeEffectStyle(.hard, for: .top)        // 🆕 Hard dividing line (like iOS 18 bar)
.contentMargins(.bottom, 30, for: .scrollContent) // Extra scroll content margin
.scrollDismissesKeyboard(.immediately)          // Dismiss keyboard on scroll
.scrollClipDisabled()                           // Allow content to overflow
.scrollTransition(.interactive, axis: .horizontal) { content, phase in
    content.scaleEffect(1.0 - 0.1 * abs(phase.value))
}                                               // 🆕 Interactive scroll animations

// MARK: - TabView (iOS 26)
.tabViewStyle(.sidebarAdaptable)                // 🆕 Tab → Sidebar on iPad
.tabBarMinimizeBehavior(.onScrollDown)          // 🆕 Hide tab bar on scroll
Tab(role: .search) { }                          // 🆕 Built-in search tab

// MARK: - Layout
.containerRelativeFrame(.horizontal)            // Width relative to container
.containerRelativeFrame([.horizontal, .vertical]) { length, axis in length }
.contentMargins(16, for: .scrollContent)        // Scroll content inset

// MARK: - Materials
.background(.ultraThinMaterial)                 // Barely visible frost
.background(.regularMaterial)                   // Standard frost
.background(.regularMaterial, in: .rect(cornerRadius: 8))  // Material with shape
MeshGradient(width: 2, height: 2, points: [...], colors: [...])  // 🆕 Complex gradient

// MARK: - Standard Patterns
List { }.listStyle(.insetGrouped)               // Default list
Form { }                                        // Form container
.sheet(isPresented:) { NavigationStack { } }    // Modal
ContentUnavailableView("Title", systemImage: "icon", description: ...)  // Empty state
.confirmationDialog(title:isPresented:titleVisibility:)  // Destructive confirm
.interactiveDismissDisabled(model.hasChanges)   // Prevent accidental dismiss

// MARK: - Previews (iOS 26 Style)
#Preview {
    @Previewable @State var data = DataSource()
    @Previewable @Namespace var namespace
    ContentView()
        .environment(data)
}
```

---

## 19. Apple Documentation Links

### HIG (Human Interface Guidelines)

| Topic | URL |
|---|---|
| HIG Home | https://developer.apple.com/design/human-interface-guidelines/ |
| What's New in Design | https://developer.apple.com/design/whats-new/ |
| Color | https://developer.apple.com/design/human-interface-guidelines/color |
| Typography | https://developer.apple.com/design/human-interface-guidelines/typography |
| Materials & Glass | https://developer.apple.com/design/human-interface-guidelines/materials |
| Icons & SF Symbols | https://developer.apple.com/design/human-interface-guidelines/icons |
| Layout | https://developer.apple.com/design/human-interface-guidelines/layout |
| Navigation | https://developer.apple.com/design/human-interface-guidelines/navigation |
| Toolbars | https://developer.apple.com/design/human-interface-guidelines/toolbars |
| Lists & Tables | https://developer.apple.com/design/human-interface-guidelines/lists-and-tables |
| Search | https://developer.apple.com/design/human-interface-guidelines/search |
| Sheets | https://developer.apple.com/design/human-interface-guidelines/sheets |
| Accessibility | https://developer.apple.com/design/human-interface-guidelines/accessibility |

### WWDC25 — Essential Sessions

| Session | URL |
|---|---|
| Meet Liquid Glass | https://developer.apple.com/videos/play/wwdc2025/219/ |
| What's New in SwiftUI | https://developer.apple.com/videos/play/wwdc2025/256/ |
| Build a SwiftUI App with the New Design | https://developer.apple.com/videos/play/wwdc2025/323/ |
| Get to Know the New Design System | https://developer.apple.com/videos/play/wwdc2025/ |

### SwiftUI API Documentation

| Topic | URL |
|---|---|
| SwiftUI Documentation | https://developer.apple.com/documentation/swiftui |
| glassEffect | https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:) |
| Applying Liquid Glass to Custom Views | https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views |
| Adopting Liquid Glass | https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass |
| GlassEffectContainer | https://developer.apple.com/documentation/swiftui/glasseffectcontainer |
| navigationTransition | https://developer.apple.com/documentation/swiftui/navigationtransition |
| matchedTransitionSource | https://developer.apple.com/documentation/swiftui/view/matchedtransitionsource(id:in:configuration:) |
| backgroundExtensionEffect | https://developer.apple.com/documentation/SwiftUI/View/backgroundExtensionEffect() |
| scrollEdgeEffectStyle | https://developer.apple.com/documentation/swiftui/view/scrolledgeeffectstyle(_:for:) |
| contentMargins | https://developer.apple.com/documentation/swiftui/view/contentmargins(_:_:for:) |
| containerRelativeFrame | https://developer.apple.com/documentation/swiftui/view/containerrelativeframe(_:alignment:) |
| MeshGradient | https://developer.apple.com/documentation/swiftui/meshgradient |
| ContentUnavailableView | https://developer.apple.com/documentation/swiftui/contentunavailableview |

### Sample Code

| Sample | URL |
|---|---|
| Wishlist — Planning Travel in SwiftUI | https://developer.apple.com/documentation/swiftui/wishlist-planning-travel-in-a-swiftui-app |
| Landmarks — Applying background extension effect | https://developer.apple.com/documentation/SwiftUI/Landmarks-Applying-a-background-extension-effect |
| Landmarks app (SwiftUI) | https://developer.apple.com/tutorials/swiftui |

### Other Frameworks

| Topic | URL |
|---|---|
| Vision Framework | https://developer.apple.com/documentation/vision |
| AVFoundation Capture | https://developer.apple.com/documentation/avfoundation/capture_setup |
| CoreML | https://developer.apple.com/documentation/coreml |
| CreateML Image Classifier | https://developer.apple.com/documentation/createml/creating-an-image-classifier-model |
| VNCalculateImageAestheticsScoresRequest (iOS 18+) | https://developer.apple.com/documentation/vision/vncalculateimageaestheticsscoresrequest |
| SF Symbols App | https://developer.apple.com/sf-symbols/ |
| SwiftData | https://developer.apple.com/documentation/swiftdata |
| PhotosUI | https://developer.apple.com/documentation/photokit/photokit-for-swiftui |
| Core Motion | https://developer.apple.com/documentation/coremotion |

---

---

## Changelog

| Version | Date | Changes |
|---|---|---|
| 1.0 | April 2026 | Initial iOS 26 draft |
| 2.0 | May 2026 | Full WWDC25 update; verified against Wishlist sample app |
| 2.1 | May 2026 | **Corrections**: SF Symbols 6→7 (6,900+); `.identity` glass style; `.close` vs `.cancel` semantics; `.subtitle`/`.largeSubtitle`/`.largeTitle` toolbar placements; `toolbarRole(.editor)` klarifikasi; `navigationSubtitle`; SF Symbols 7 Draw/Gradient APIs |

*Sources: Apple HIG, WWDC25 session transcripts (219, 256, 291, 323, 337), Apple official sample code (WishlistPlanningTravelInASwiftUIApp), Apple Developer Documentation (copyright © 2026 Apple Inc.)*
