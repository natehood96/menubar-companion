# Create New Skill

You are creating a new MenuBot skill. A skill is a markdown file containing instructions that any MenuBot doer or orchestrator can read and follow to accomplish a specific type of task.

## What You Need to Do

1. **Write the skill markdown file** at `~/Library/Application Support/MenuBot/skills/<skill-id>.md`
2. **Update the skills index** at `~/Library/Application Support/MenuBot/skills/skills-index.json` to register the new skill

## Skill File Format

The markdown file should contain:
- A clear title (H1 heading)
- What this skill does
- Step-by-step instructions or patterns for how to accomplish the task
- Any setup requirements (installs, API keys, etc.)
- Tips for best results
- A "When to Use This Skill" section at the bottom

Write it as instructions TO an AI agent. Be specific and actionable. Include code examples, CLI commands, or API patterns the agent should use.

## Updating the Skills Index

Read the current index:
```bash
cat ~/Library/Application\ Support/MenuBot/skills/skills-index.json
```

Then write the updated index with your new skill appended. The index is a JSON array:

```json
[
  {
    "id": "your-skill-id",
    "name": "Human Readable Name",
    "description": "One sentence explaining when this skill is useful.",
    "icon": "sf.symbol.name",
    "category": "Category",
    "file": "your-skill-id.md"
  }
]
```

**Rules for the index entry:**
- `id`: kebab-case, unique, descriptive (e.g., `send-slack-message`, `provision-twilio-number`)
- `name`: Short, clear, title-cased
- `description`: One sentence — should make it obvious when to use this skill
- `icon`: A valid SF Symbol name (e.g., `globe`, `envelope`, `phone`, `hammer`, `gear`)
- `category`: One of: Tools, Productivity, Communication, Development, System, or a new category if none fit
- `file`: The filename of the markdown file you just created

## Important

- Do NOT remove or modify existing entries in the index — only append your new one.
- Make sure the JSON is valid after your edit.
- The skill should be genuinely reusable — not a one-off script. It should help any future task of the same type.

## When to Use This Skill

- You figured out how to do something novel (used a new API, integrated with a service, automated a workflow)
- The orchestrator asks you to document a capability as a new skill
- You want to save a reusable pattern for future tasks
