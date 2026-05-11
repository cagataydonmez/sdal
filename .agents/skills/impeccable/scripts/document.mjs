#!/usr/bin/env node
import fs from 'fs';
import path from 'path';

const contextDir = process.env.IMPECCABLE_CONTEXT_DIR || process.cwd();
const designPath = path.join(contextDir, 'DESIGN.md');

const designContent = `# Design System

## Overview
Document the design tokens and visual language for this project.

## Color Palette
Define your colors in OKLCH or HSL:
- Primary accent
- Neutrals (grays)
- Semantic colors (success, warning, danger, info)
- Dark mode variants

## Typography
- Font families
- Scale (heading, body, label sizes)
- Line heights and spacing
- Hierarchy rules

## Spacing
Define your spacing scale:
- 4px, 8px, 12px, 16px, 20px, 24px, etc.

## Border Radius
- XS: 4-8px (small, tight elements)
- SM: 8-12px (buttons, inputs)
- MD: 12-16px (cards, containers)
- LG: 16-20px (large surfaces)
- XL: 20-24px (hero sections)

## Components
Document key UI components:
- Buttons (primary, secondary, tertiary)
- Cards
- Forms and inputs
- Navigation
- Modals/Dialogs
- Loading states
- Error states

## Elevation/Shadows
Define your shadow system for depth:
- Subtle
- Medium
- Prominent

## Motion
- Transition curves and durations
- Animation principles
- Micro-interactions

## Responsive Breakpoints
- Mobile: 320px-480px
- Tablet: 481px-1024px
- Desktop: 1025px+

## Accessibility
- Contrast ratios
- Touch targets
- Focus states
- ARIA guidelines

## Dark Mode
Describe how colors, shadows, and interactions adapt in dark mode.
`;

fs.writeFileSync(designPath, designContent, 'utf8');
console.log(`✅ Created/updated ${designPath}\n`);
console.log('Edit this file with your actual design specifications.');
