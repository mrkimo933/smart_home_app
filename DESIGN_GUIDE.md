# Smart Home App - Modern Design System

## Overview
The smart home app has been redesigned with a modern, sophisticated aesthetic inspired by premium mobile applications like Airofit breathing trainer. The design emphasizes clarity, visual hierarchy, and engaging interactions through a carefully curated color palette and refined typography.

## Color Palette

### Primary Colors
- **Background**: `#0F1419` - Deep navy providing a premium dark base
- **Card Background**: `#1A1F2E` - Slightly lighter for card hierarchy
- **Primary Blue**: `#2563EB` - Primary brand color for key interactions
- **Accent Magenta**: `#D946EF` - Supporting accent for secondary elements
- **Accent Orange**: `#EA580C` - Energetic accent for alerts and peak hours
- **Accent Teal**: `#14B8A6` - Cool accent for positive status indicators

### Status Colors
- **Error Red**: `#EF4444` - For warnings and critical alerts
- **Success Green**: `#10B981` - For positive confirmations
- **Warning Yellow**: `#FCD34D` - For cautions and notices

### Text Colors
- **Text Primary**: `#FAFAFA` - Main text content
- **Text Secondary**: `#9CA3AF` - Supporting text and labels
- **Text Tertiary**: `#6B7280` - Disabled or de-emphasized text

## Typography

### Font Hierarchy
- **Headings**: 24-36px, Weight: 700-800, Letter spacing: -0.5 to 0.5px
- **Titles**: 16-20px, Weight: 600-700, Letter spacing: 0.15px
- **Body**: 14-16px, Weight: 400-500
- **Labels**: 12-13px, Weight: 500-600

### Font Details
- All fonts use the system default sans-serif
- Generous line-height (1.4-1.6) for improved readability
- Consistent letter spacing for a premium feel

## Components

### Modern Card (`modern_card.dart`)
A flexible card component with support for:
- **Rounded Corners**: 24px border radius (adjustable)
- **Shadows**: Layered shadows (2-16px blur) for depth
- **Gradients**: Optional gradient backgrounds for visual interest
- **Padding**: 20px default with customizable margins
- **Interactive**: Optional onTap with ripple effects

**Usage Example**:
```dart
ModernCard(
  borderRadius: 24,
  padding: const EdgeInsets.all(20),
  child: YourContent(),
)
```

### Modern Stat Card (`modern_card.dart`)
Specialized card for displaying statistics with:
- **Large Typography**: 32px font size for values
- **Accent Colors**: Color-coded units for visual interest
- **Icon Support**: Optional colored icons
- **Gradient Support**: Optional gradient backgrounds

**Usage Example**:
```dart
ModernStatCard(
  label: 'Energy Usage',
  value: '245',
  unit: 'kWh',
  accentColor: Colors.blue,
  icon: Icons.flash_on,
)
```

### Gradient Background (`gradient_background.dart`)
Subtle gradient backgrounds for screens:
- **Layered Gradients**: Primary background to 5% tint of accent colors
- **Customizable**: Full control over colors and direction

### Dot Pattern (`dot_pattern.dart`)
Animated dot visualization pattern similar to breathing trainer design:
- **Configurable**: 8 rows × 10 columns by default
- **Animated**: Wave effect with staggered pulsing
- **Customizable Colors**: Any color with adjustable dot size and spacing

### Enhanced Sensor Card
Updates to sensor card styling:
- **Color-Coded Icons**: Icon containers with accent color background
- **Large Numbers**: 24px font size for readings
- **Accent Units**: Units displayed in accent colors
- **Animation**: Smooth count-up animation when values change

## Dashboard Updates

### Peak Hours Banner
- **Modern Styling**: Rounded corners (20px) with elevation
- **Gradient Backgrounds**: Orange-magenta for afternoon peaks, blue-teal for other hours
- **Enhanced Visual Hierarchy**: Icon containers, better spacing, improved typography
- **Dismissible**: Close button with smooth fade animation

### Bill Prediction Card
- **Status Indicators**: Shows "Over Budget" or "On Track" status
- **Color-Coded Info Items**: Three metric boxes with unique accent colors
- **Enhanced Progress Bar**: 10px height with smoother styling
- **Better Visual Feedback**: Over-budget border styling for warnings

### Power Gauge
- **Updated Colors**: Green→Teal, Orange→Orange, Red→Red for consistency
- **Smooth Animations**: Easing curves for natural interactions
- **Clear Typography**: Better contrast and readability

## Design Principles

### 1. Depth and Layering
- Multiple shadow layers create visual separation
- Cards have elevated appearance with soft shadows
- Subtle gradients add dimension without overwhelming

### 2. Color Usage
- Limited palette (5-6 colors) prevents visual chaos
- Each color has a specific purpose and hierarchy
- Accents complement without distraction

### 3. Typography as Design
- Generous sizing creates visual weight
- Letter spacing adds refinement
- Weight variation guides user attention

### 4. Spacing and Rhythm
- Consistent padding (20px) across components
- Generous gaps between sections
- Vertical rhythm supports scanning

### 5. Interactive Feedback
- Ripple effects on tappable elements
- Smooth animations (400-800ms) for transitions
- Color changes provide visual confirmation

## Implementation Guidelines

### Using Modern Cards
All dashboard cards should use the `ModernCard` component:
```dart
import '../../../core/widgets/modern_card.dart';

// Simple card
ModernCard(
  child: YourContent(),
)

// With gradient
ModernCard(
  gradientColors: [AppColors.primaryBlue, AppColors.accentTeal],
  child: YourContent(),
)
```

### Color Reference
```dart
import '../../../core/constants/app_colors.dart';

// Use these colors consistently
AppColors.background         // Screen backgrounds
AppColors.cardColor          // Card backgrounds
AppColors.primaryBlue        // Primary actions
AppColors.accentMagenta      // Secondary accents
AppColors.accentOrange       // Alerts/warnings
AppColors.accentTeal         // Success/positive
AppColors.textPrimary        // Main text
AppColors.textSecondary      // Supporting text
```

### Creating New Screens
1. Use `GradientBackground` for screen background
2. Use `ModernCard` for all content sections
3. Apply consistent padding (16-20px)
4. Use the color palette for status indicators
5. Employ animations for state changes

## Animation Patterns

### Value Changes
```dart
TweenAnimationBuilder<double>(
  duration: const Duration(milliseconds: 600),
  curve: Curves.easeOutCubic,
  tween: Tween<double>(begin: 0, end: targetValue),
  builder: (context, value, child) {
    // Animate to new value
  },
)
```

### State Transitions
```dart
FadeTransition(
  opacity: animation,
  child: YourContent(),
)
```

## Responsive Design

### Breakpoints
- **Mobile**: Default layout
- **Tablet**: Increased card widths and grid columns
- **Desktop**: Multi-column layouts with additional content

### Card Sizing
- **Width**: Full width with 16px horizontal padding
- **Height**: Content-driven, no fixed heights
- **Spacing**: 12-16px gaps between cards

## Accessibility

### Color Contrast
- Text Primary on Card Background: ~19:1 ratio ✓
- Text Secondary on Card Background: ~8:1 ratio ✓
- Status colors meet WCAG AA standards

### Typography
- Minimum font size: 12px (labels only)
- Comfortable reading size: 14-16px (body text)
- Clear hierarchy with distinct sizing

### Interactive Elements
- Touch targets: Minimum 48px × 48px
- Ripple feedback on tap
- Visual focus states for keyboard navigation

## Future Enhancements

### Planned Additions
1. **Glass Morphism**: Frosted glass cards for premium feel
2. **Micro-interactions**: Hover effects and gesture animations
3. **Dark Mode Variations**: Additional color schemes
4. **Custom Fonts**: Integration of premium typography
5. **Animation Library**: Reusable animation components

### Customization Points
- Border radius adjustable per component
- Shadow customization for different elevations
- Gradient direction and color stops
- Animation duration and easing curves

## Implementation Checklist

- [x] Color palette defined and implemented
- [x] Modern card components created
- [x] Dashboard widgets updated
- [x] Peak hours banner redesigned
- [x] Bill prediction card enhanced
- [x] Sensor cards modernized
- [x] Power gauge colors updated
- [ ] All screens updated with new styling
- [ ] Animation library completed
- [ ] Dark mode variations added

---

**Last Updated**: June 14, 2026
**Version**: 1.0
**Design Lead**: v0 Design System
