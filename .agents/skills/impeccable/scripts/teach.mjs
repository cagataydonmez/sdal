#!/usr/bin/env node
import fs from 'fs';
import path from 'path';
import readline from 'readline';

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

const question = (prompt) => new Promise((resolve) => rl.question(prompt, resolve));

const contextDir = process.env.IMPECCABLE_CONTEXT_DIR || process.cwd();
const productPath = path.join(contextDir, 'PRODUCT.md');
const designPath = path.join(contextDir, 'DESIGN.md');

async function teach() {
  console.log('\n🎨 Impeccable Teach: Set up PRODUCT.md and DESIGN.md\n');

  // Gather product information
  console.log('--- PRODUCT.MD SETUP ---\n');
  const productName = await question('Project/Product name: ');
  const users = await question('Who uses this? (e.g., "Community members, event organizers"): ');
  const purpose = await question('What is the product purpose? (e.g., "Community event discovery and RSVP platform"): ');
  const tone = await question('Brand tone? (e.g., "Warm, professional, Turkish-friendly"): ');
  const register = await question('Is this brand (marketing/landing) or product (app UI)? [brand/product]: ');
  const antiRefs = await question('Anti-references? (e.g., "Generic event apps, cluttered calendars"): ');

  // Create PRODUCT.md
  const productContent = `# Product Context

## Product
${productName}

## Users
${users}

## Product Purpose
${purpose}

## Brand Tone
${tone}

## Strategic Principles
- Design serves product functionality
- Clarity over complexity
- User-centered approach

## Register
${register}

## Anti-references
${antiRefs}
`;

  fs.writeFileSync(productPath, productContent, 'utf8');
  console.log(`\n✅ Created ${productPath}`);

  // Gather design information
  console.log('\n--- DESIGN.MD SETUP ---\n');
  const primaryColor = await question('Primary/accent color (hex)? [e.g., #B45637]: ');
  const typography = await question('Typography approach? [e.g., "Material 3, clean hierarchy"]: ');
  const spacing = await question('Standard spacing unit? [e.g., "4px, 8px, 12px, 16px, 20px"]: ');
  const radius = await question('Border radius tokens? [e.g., "8px, 12px, 16px, 20px"]: ');

  // Create DESIGN.md
  const designContent = `# Design System

## Color Palette
- Primary/Accent: ${primaryColor}
- Neutrals: Tinted grays
- Semantic: Success, warning, danger, info

## Typography
${typography}

## Spacing
${spacing}

## Border Radius
${radius}

## Components
Document your key UI components and their patterns here.

## Dark Mode
Support both light and dark modes with thoughtful contrast.
`;

  fs.writeFileSync(designPath, designContent, 'utf8');
  console.log(`✅ Created ${designPath}`);

  console.log('\n✨ Setup complete! You can now use impeccable commands.\n');
  console.log('Next steps:');
  console.log('  - Edit PRODUCT.md and DESIGN.md with more details');
  console.log('  - Run: node .agents/skills/impeccable/scripts/load-context.mjs');
  console.log('  - Use impeccable commands: /impeccable craft, /impeccable shape, etc.\n');

  rl.close();
}

teach().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
