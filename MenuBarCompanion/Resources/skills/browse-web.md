# Browse Web (Playwright MCP + Brave)

You have access to a web browser via Playwright MCP tools. These give you direct browser control through tool calls — no scripts needed.

## Setup

MenuBot auto-registers the Playwright MCP server on launch. You should already have these tools available:

- `mcp__playwright__browser_navigate` — Go to a URL
- `mcp__playwright__browser_snapshot` — Get the page's accessibility tree with ref IDs
- `mcp__playwright__browser_click` — Click an element by ref ID
- `mcp__playwright__browser_type` — Type text into a focused element
- `mcp__playwright__browser_fill_form` — Fill a form field by ref ID
- `mcp__playwright__browser_press_key` — Press a key (Enter, Tab, etc.)
- `mcp__playwright__browser_select_option` — Select from a dropdown
- `mcp__playwright__browser_hover` — Hover over an element
- `mcp__playwright__browser_take_screenshot` — Take a screenshot (visual confirmation)
- `mcp__playwright__browser_evaluate` — Run JavaScript on the page
- `mcp__playwright__browser_wait_for` — Wait for an element or condition
- `mcp__playwright__browser_navigate_back` — Go back
- `mcp__playwright__browser_tabs` — List open tabs
- `mcp__playwright__browser_close` — Close the browser

If these tools are NOT available, register the MCP server manually:

```bash
claude mcp add --scope user playwright -- npx @playwright/mcp@latest --browser chromium --executable-path "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"
```

If Brave is not installed:

```bash
brew install --cask brave-browser
```

## How to Use — Interactive, One Step at a Time

**CRITICAL: Do NOT write scripts.** You drive the browser interactively, one tool call at a time, making decisions based on what you see.

### The Pattern

1. **Navigate** to the target URL with `browser_navigate`.

2. **Snapshot** the page with `browser_snapshot` to get the accessibility tree. This returns every interactive element with a `ref` ID. Use these refs for all interactions — never guess at selectors.

3. **Decide what to do.** Based on the snapshot, pick the next action: click a button, fill a field, select an option. Use the ref ID from the snapshot.

4. **Act** — one action at a time. Click, type, fill, press a key.

5. **Snapshot again.** After every action that changes the page, re-snapshot. Refs go stale after navigation or state changes.

6. **Repeat** until the task is done.

### Example Flow

```
1. browser_navigate → "https://www.google.com/travel/flights"
2. browser_snapshot → see the search form, note ref IDs for origin/destination fields
3. browser_click → click the origin field (ref: "e42")
4. browser_type → type "SLC"
5. browser_snapshot → see the autocomplete dropdown, note the ref for "Salt Lake City"
6. browser_click → click the SLC suggestion (ref: "e58")
7. browser_snapshot → origin is set, now find destination field
8. browser_click → click destination field
9. browser_type → type "Dublin"
... and so on
```

### Why This Works

- You see the real page state (accessibility tree) before every action.
- You adapt to whatever is on screen — popups, banners, dynamic content.
- No brittle selectors or hardcoded waits. You react to what's actually there.
- Complex flows (date pickers, dropdowns, multi-step forms) are easy because you decide each step.

## Tips

- **Snapshot before every interaction.** Refs go stale after clicks or navigation.
- **Use `browser_evaluate` for quick checks** (page title, element count, text content) — cheaper than a full snapshot.
- **Use `browser_take_screenshot`** for visual confirmation when the accessibility tree isn't enough (charts, images, layout issues).
- For JS-heavy sites (Google Flights, Google Maps), use `browser_wait_for` after actions that trigger loading.
- If the browser fails to launch, check that Brave is installed at `/Applications/Brave Browser.app/`.
- If you need to handle login flows, ask the user for credentials via `[ASK_USER]`.

## When to Use This Skill

- User asks you to look something up on a website
- User asks you to scrape or extract data from a web page
- User asks you to interact with a web app (fill forms, click buttons, navigate)
- User asks you to take a screenshot of a website
- You need real-time data from the web that search tools can't provide
