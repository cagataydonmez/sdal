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
const shapePath = path.join(contextDir, '.claude', 'shape.md');

async function shape() {
  console.log('\n🎯 Shape Mode: Plan your design before building\n');

  const feature = await question('Feature/component to design: ');
  const userNeed = await question('What user problem does this solve? ');
  const success = await question('How will you know it works? (success criteria): ');
  const layout = await question('Proposed layout approach: ');
  const interactions = await question('Key interactions/flows: ');
  const constraints = await question('Any design constraints? ');

  const shapeContent = `# Design Shape: ${feature}

## Feature Brief
${feature}

## User Need
${userNeed}

## Success Criteria
${success}

## Layout Approach
${layout}

## Key Interactions
${interactions}

## Constraints
${constraints}

## Visual Direction
[Describe the visual direction: colors, typography, spacing, etc.]

## Responsive Behavior
[How should this adapt to different screen sizes?]

## Accessibility Notes
[Any a11y considerations?]

## Open Questions
- [ ] Question 1?
- [ ] Question 2?

## Status
- [ ] Design brief confirmed
- [ ] Wireframes ready
- [ ] Visual specs defined
- [ ] Ready to implement
`;

  // Create .claude directory if it doesn't exist
  const claudeDir = path.dirname(shapePath);
  if (!fs.existsSync(claudeDir)) {
    fs.mkdirSync(claudeDir, { recursive: true });
  }

  fs.writeFileSync(shapePath, shapeContent, 'utf8');
  console.log(`\n✅ Created ${shapePath}\n`);
  console.log('Next: Review the brief above and confirm if the direction is right.\n');

  rl.close();
}

shape().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
