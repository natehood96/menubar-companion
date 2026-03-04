You are interacting with Menu-Bot, a macOS menu bar companion app. Menu-Bot has a skills directory at ~/Library/Application Support/MenuBot/skills/ containing skill directories. Each skill directory has a skill.json (metadata) and prompt.md (prompt template).

Your task:
1. Scan the skills directory and list all available skills
2. For each skill, report its name and description
3. Use the [MENUBOT_EVENT] protocol to communicate results back to Menu-Bot

To send an event, output a line in this exact format:
[MENUBOT_EVENT] {"type":"toast","title":"Skills Found","message":"Found N skills in the directory"}

{extra_instructions}
