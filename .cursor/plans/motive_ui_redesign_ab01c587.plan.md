---
name: Motive UI Redesign
overview: Complete UI/UE overhaul of Motive, introducing a new "Aurora" design system with gradient-infused dark theme, refined typography, consistent spacing, micro-interactions, and enhanced visual hierarchy while preserving all existing functionality.
todos:
  - id: design-system
    content: Create AuroraTheme.swift with all design tokens (colors, typography, spacing, radius, animations)
    status: completed
  - id: aurora-components
    content: Build reusable Aurora components (GradientBorder, GlowEffect, AuroraButton, AuroraTextField)
    status: completed
  - id: commandbar-redesign
    content: Redesign CommandBarView with gradient border, new typography, and animations
    status: completed
  - id: drawer-redesign
    content: Redesign DrawerView and DrawerComponents with new message bubbles and layout
    status: completed
  - id: settings-redesign
    content: Redesign SettingsView, SettingsCard, and SettingsRow with Aurora theme
    status: completed
  - id: model-config-redesign
    content: Redesign ModelConfigView with provider cards and gradient selections
    status: completed
  - id: permission-redesign
    content: Redesign PermissionRequestView and QuickConfirmView with new modal styles
    status: completed
  - id: onboarding-redesign
    content: Apply Aurora theme to OnboardingView
    status: completed
  - id: status-components
    content: Update StatusBarController and StatusNotificationView with new states
    status: completed
  - id: cleanup-legacy
    content: Remove old DesignSystem.swift code and ensure consistent token usage across all files
    status: completed
isProject: false
---

# Motive UI/UE Complete Redesign: Aurora Design System

## Vision Statement

Transform Motive from a monochrome glass-morphism interface into an **Aurora Design System** - a sophisticated, gradient-infused dark-first experience that feels alive with subtle energy. The design language draws inspiration from the northern lights: deep space backgrounds with hints of color that pulse and flow, creating an interface that feels intelligent and responsive.

---

## 1. Design Philosophy Shift

### Current State Problems

- Monochrome palette lacks emotional resonance and feels cold
- Inconsistent use of design tokens (hardcoded values everywhere)
- Status colors (blue/green/red) conflict with monochrome system
- Glass morphism effects are heavy and obscure content
- Typography hierarchy is weak with small font sizes

### Aurora Philosophy

- **Living Interface**: Subtle gradients and animations that respond to AI activity
- **Depth Through Light**: Use light and color strategically, not opacity
- **Confident Typography**: Larger, bolder text with clear hierarchy
- **Intentional Motion**: Every animation has purpose and meaning
- **Seamless Dark Mode**: Dark-first design with considered light mode

---

## 2. Color System Redesign

### Primary Palette

```
Aurora Colors (Dark Mode Primary):
- Background Deep:    #0A0A0F (base canvas)
- Background:         #12121A (elevated surfaces)
- Surface:            #1A1A24 (cards, inputs)
- Surface Elevated:   #222230 (hover states)

Accent Gradient:
- Aurora Start:       #6366F1 (Indigo)
- Aurora Mid:         #8B5CF6 (Violet)
- Aurora End:         #EC4899 (Pink)

Semantic Colors:
- Success:            #10B981 (Emerald)
- Warning:            #F59E0B (Amber)
- Error:              #EF4444 (Red)
- Info:               #3B82F6 (Blue)

Text Hierarchy:
- Primary:            #FAFAFA (98% white)
- Secondary:          #A1A1AA (zinc-400)
- Muted:              #71717A (zinc-500)
- Disabled:           #52525B (zinc-600)

Border Colors:
- Default:            rgba(255,255,255,0.06)
- Hover:              rgba(255,255,255,0.12)
- Focus:              rgba(99,102,241,0.5) (Aurora gradient)
```

### Light Mode Adaptation

```
Light Mode Colors:
- Background:         #FAFAFA
- Surface:            #FFFFFF
- Surface Elevated:   #F4F4F5

Text:
- Primary:            #18181B
- Secondary:          #52525B
- Muted:              #A1A1AA
```

---

## 3. Typography System

### Font Stack

- **Primary**: SF Pro Display (headlines), SF Pro Text (body)
- **Monospace**: SF Mono (code, technical info)
- **Alternative**: Inter (if SF Pro unavailable)

### Type Scale

```
Display:     32pt / Bold / -0.02em tracking
Title 1:     24pt / Semibold / -0.01em
Title 2:     20pt / Semibold / -0.01em
Headline:    17pt / Semibold
Body:        15pt / Regular / 1.5 line-height
Body Small:  14pt / Regular
Caption:     12pt / Medium
Micro:       11pt / Medium / 0.02em tracking
```

### Key Changes

- Increase base body size from 13-14pt to 15pt
- Use semibold for headlines instead of medium
- Add negative letter-spacing for large text
- Consistent line-height ratios

---

## 4. Spacing System

### Base Unit: 4px

```
Space:
- 0.5:  2px   (micro gaps)
- 1:    4px   (tight)
- 2:    8px   (compact)
- 3:    12px  (default gap)
- 4:    16px  (standard)
- 5:    20px  (comfortable)
- 6:    24px  (sections)
- 8:    32px  (large sections)
- 10:   40px  (page padding)
- 12:   48px  (hero spacing)
```

### Corner Radius

```
Radius:
- xs:   4px   (badges, tags)
- sm:   6px   (buttons, inputs)
- md:   10px  (cards)
- lg:   14px  (modals, panels)
- xl:   20px  (main containers)
- full: 9999px (pills, avatars)
```

---

## 5. Component Redesign

### CommandBar (The Star Component)

```
New Design:
- Width: 600px (reduced for focus)
- Background: Solid #12121A with 1px gradient border
- Border: Aurora gradient (indigo -> violet -> pink)
- No blur effect (cleaner, faster)
- Input: 20pt font, bold placeholder
- Action button: Gradient fill with glow on hover
- Footer: Minimal, only show active status
- Shadow: Large ambient glow when focused

Animation:
- Entrance: Scale 0.95 -> 1.0 with spring
- Exit: Fade + scale down 0.98
- Border gradient: Slow rotation animation (optional)
```

### Drawer (Conversation Panel)

```
New Design:
- Width: 400px (slightly wider for readability)
- Height: 600px (taller for more content)
- Background: #0A0A0F with subtle gradient
- Header: Compact, session name prominent
- Messages: Increased spacing, clear visual hierarchy

Message Bubbles:
- User: Gradient background (Aurora colors)
- Assistant: #1A1A24 with left accent border (violet)
- Tool: Compact inline with icon + monospace
- System: Subtle, muted appearance

Input Area:
- Floating style with glow on focus
- Send button: Gradient when enabled
```

### Settings Window

```
New Design:
- Size: 760px x 560px
- Sidebar: Darker (#0A0A0F) with gradient active state
- Navigation: Larger icons, better spacing
- Content: Card-based sections with clear labels
- Forms: Consistent input styling with focus states

Provider Cards (Model tab):
- Visual identity with provider colors
- Selected state: Gradient border + check
- Hover: Subtle lift effect
```

### MenuBar Status

```
New Design:
- Idle: Subtle pulsing glow
- Thinking: Aurora gradient animation
- Executing: Solid accent color pulse
- States have distinct visual signatures
```

### Quick Confirm / Permission

```
New Design:
- Frosted glass effect (lighter than before)
- Clear icon with semantic color background
- Action buttons: Primary gradient, secondary outline
- Improved file path display with syntax highlighting
```

---

## 6. Animation System

### Timing Functions

```
Easing:
- ease-out:     cubic-bezier(0.33, 1, 0.68, 1)
- ease-in-out:  cubic-bezier(0.65, 0, 0.35, 1)
- spring:       response: 0.3, damping: 0.7
- springBouncy: response: 0.4, damping: 0.6

Duration:
- instant:      100ms (micro-interactions)
- fast:         150ms (hovers, toggles)
- normal:       250ms (transitions)
- slow:         400ms (complex animations)
```

### Key Animations

```
Micro-interactions:
- Button press: scale(0.97) + brightness
- Hover: translateY(-1px) + shadow increase
- Focus: Ring animation + glow pulse

Transitions:
- Page/Tab: Crossfade with slide
- Modal: Scale + fade from center
- Drawer: Slide from edge with spring

Status Animations:
- Thinking: Shimmer gradient flow
- Processing: Pulsing glow ring
- Success: Checkmark draw + burst
- Error: Shake + flash
```

---

## 7. Iconography

### Icon Style

- Use SF Symbols with `.regular` weight
- Size: 16px (default), 20px (emphasis), 12px (inline)
- Semantic coloring for status icons

### Custom Icons Needed

- App logo refresh (Aurora theme)
- Status bar icon variants
- Empty state illustrations

---

## 8. Implementation Architecture

### File Structure Changes

```
/UI
  /DesignSystem
    AuroraTheme.swift       # Colors, fonts, spacing constants
    AuroraComponents.swift  # Reusable components
    AuroraAnimations.swift  # Animation presets
    AuroraModifiers.swift   # View modifiers
  /CommandBar
    CommandBarView.swift    # Redesigned
  /Drawer
    DrawerView.swift        # Redesigned
    MessageBubble.swift     # New component
    ChatInput.swift         # New component
  /Settings
    SettingsView.swift      # Redesigned
    ProviderCard.swift      # New component
  /Shared
    GradientBorder.swift    # Aurora gradient border
    GlowEffect.swift        # Ambient glow modifier
    ShimmerEffect.swift     # Improved shimmer
```

### Design Token Implementation

Use `@Environment` and `@EnvironmentObject` for theming:

```swift
// AuroraTheme.swift
struct AuroraTheme {
    let colors: AuroraColors
    let typography: AuroraTypography
    let spacing: AuroraSpacing
    let radius: AuroraRadius
    let animation: AuroraAnimation
}

// Usage
@Environment(\.auroraTheme) var theme
```

---

## 9. Key Files to Modify

| File | Changes |

|------|---------|

| [`DesignSystem.swift`](Motive/UI/DesignSystem.swift) | Complete rewrite with Aurora theme |

| [`CommandBarView.swift`](Motive/UI/CommandBar/CommandBarView.swift) | New visual design, gradient border |

| [`DrawerView.swift`](Motive/UI/Drawer/DrawerView.swift) | Layout refresh, new message styles |

| [`DrawerComponents.swift`](Motive/UI/Drawer/DrawerComponents.swift) | Redesigned bubbles and indicators |

| [`SettingsView.swift`](Motive/UI/Settings/SettingsView.swift) | New sidebar and content styling |

| [`ModelConfigView.swift`](Motive/UI/Settings/ModelConfigView.swift) | Provider cards redesign |

| [`GeneralSettingsView.swift`](Motive/UI/Settings/GeneralSettingsView.swift) | Form styling updates |

| [`PermissionRequestView.swift`](Motive/UI/Permission/PermissionRequestView.swift) | New modal design |

| [`QuickConfirmView.swift`](Motive/UI/QuickConfirm/QuickConfirmView.swift) | Compact redesign |

| [`OnboardingView.swift`](Motive/UI/Onboarding/OnboardingView.swift) | Aurora-themed onboarding |

| [`StatusNotificationView.swift`](Motive/UI/StatusNotification/StatusNotificationView.swift) | Toast redesign |

| [`StatusBarController.swift`](Motive/App/StatusBarController.swift) | Status display updates |

---

## 10. Visual Mockup Descriptions

### CommandBar

```
+----------------------------------------------------------+
|  [gradient border glowing softly]                          |
|                                                            |
|    What would you like me to do?                           |
|    [large 20pt placeholder text, muted]                    |
|                                                            |
|                                            [Run ->]        |
|                                      [gradient button]     |
|                                                            |
|  ------------------------------------------------          |
|  [dim footer: ↵ Run  esc Close  ⌘, Settings]              |
+----------------------------------------------------------+
```

### Drawer

```
+----------------------------------------+
|  [=] Session Name              [+] [x] |
|  [gradient accent bar]                  |
|----------------------------------------|
|                                        |
|  [User message - gradient bg, right]   |
|                                        |
|  [Assistant - dark bg, left border]    |
|  Sparkle icon + response text          |
|                                        |
|  [Tool] icon + tool_name + args        |
|  [compact, inline, monospace]          |
|                                        |
|----------------------------------------|
|  [Input field with glow]    [->]       |
+----------------------------------------+
```

---

## 11. Estimated Impact

### Performance

- Removing heavy blur effects will improve rendering
- Solid backgrounds are more performant than transparency
- Animations optimized for 60fps

### Accessibility

- Higher contrast text (4.5:1 minimum)
- Larger touch targets (44px minimum)
- Clear focus states
- Reduced motion option

### User Experience

- Clearer visual hierarchy
- Faster perceived performance
- More engaging interactions
- Consistent design language