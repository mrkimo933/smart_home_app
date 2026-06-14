# Smart Home Energy Monitor

A modern Flutter app to monitor and control smart home electricity usage with MQTT integration, featuring a premium dark-themed design system inspired by contemporary mobile applications.

## 🎨 Modern Design System

The app now features a sophisticated, modern UI with:
- **Premium Dark Theme**: Deep navy backgrounds with carefully curated accent colors
- **Custom Components**: Reusable modern card, button, and visualization components
- **Smooth Animations**: 400-800ms animations with easing curves for natural interactions
- **Accessible Design**: WCAG AA compliant contrast ratios and 48px+ touch targets
- **Visual Hierarchy**: Clear typography scale and color-coded status indicators

### Color Palette
```
Primary Blue:     #2563EB  (Main actions)
Accent Magenta:   #D946EF  (Secondary)
Accent Orange:    #EA580C  (Alerts)
Accent Teal:      #14B8A6  (Success)
Background:       #0F1419  (Premium dark)
Card Surface:     #1A1F2E  (Component backgrounds)
```

### Design Documentation

- **[DESIGN_GUIDE.md](DESIGN_GUIDE.md)** - Complete design system overview and principles
- **[DESIGN_IMPLEMENTATION.md](DESIGN_IMPLEMENTATION.md)** - Implementation details and file changes
- **[DESIGN_COMPONENTS_REFERENCE.md](DESIGN_COMPONENTS_REFERENCE.md)** - Visual component reference
- **[IMPLEMENTATION_CHECKLIST.md](IMPLEMENTATION_CHECKLIST.md)** - Development checklist and quick start

### Core Components

All dashboard widgets now use modern card components:

```dart
// ModernCard - Flexible container with elevation
ModernCard(
  borderRadius: 24,
  padding: const EdgeInsets.all(20),
  child: YourContent(),
)

// ModernStatCard - Specialized for metrics
ModernStatCard(
  label: 'Energy Usage',
  value: '245',
  unit: 'kWh',
  accentColor: Colors.blue,
  icon: Icons.flash_on,
)

// ModernButton - Variant support
ModernButton(
  label: 'Save',
  onPressed: () {},
  variant: ModernButtonVariant.primary,
)
```
