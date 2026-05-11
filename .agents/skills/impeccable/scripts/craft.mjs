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
const craftPath = path.join(contextDir, '.claude', 'craft.md');

async function craft() {
  console.log('\n🏗️  Craft Mode: Design and build a feature end-to-end\n');

  const feature = await question('Feature to craft: ');
  const scope = await question('Scope (e.g., "Single component", "Full page", "Flow with 3 screens"): ');
  const requirements = await question('Key requirements (comma-separated): ');
  const constraints = await question('Design constraints: ');

  const craftContent = `# Craft: ${feature}

## Feature Brief
${feature}

## Scope
${scope}

## Requirements
${requirements}

## Design Constraints
${constraints}

## Design Direction
[Describe visual approach, colors, typography, spacing]

## Components Needed
- [ ] Component 1
- [ ] Component 2
- [ ] Component 3

## Implementation Plan
1. [Step 1]
2. [Step 2]
3. [Step 3]

## Testing Checklist
- [ ] Desktop view
- [ ] Mobile view
- [ ] Dark mode (if applicable)
- [ ] Accessibility
- [ ] Edge cases

## Status
- [ ] Design approved
- [ ] Components built
- [ ] Tested and reviewed
- [ ] Ready to ship
`;

  // Create .claude directory if it doesn't exist
  const claudeDir = path.dirname(craftPath);
  if (!fs.existsSync(claudeDir)) {
    fs.mkdirSync(claudeDir, { recursive: true });
  }

  fs.writeFileSync(craftPath, craftContent, 'utf8');
  console.log(`\n✅ Created ${craftPath}\n`);
  console.log('Your craft brief is ready. Design and build from this plan.\n');

  rl.close();
}

craft().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
