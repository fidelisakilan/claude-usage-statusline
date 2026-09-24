# claude-usage-statusline

A one-line [Claude Code](https://claude.com/claude-code) status line: model on the left; session cost, context use, and plan usage limits on the right.

**Dark**

![status line, dark mode](screenshots/dark.png)

**Light**

![status line, light mode](screenshots/light.png)

```
Opus 5.5 (1M context)                              $0.22 · ctx 4% · 5h 12% · 7d 30%
```

| Field | Meaning |
|-------|---------|
| `$0.22` | Estimated cost of the current session (API pricing; not what a Pro/Max plan bills) |
| `ctx` | Context window used |
| `5h` | 5-hour plan usage limit used |
| `7d` | Weekly plan usage limit used |

`5h`/`7d` only appear when Claude Code provides rate-limit data (subscription plans).

## Install

Requires `jq`.

```sh
curl -o ~/.claude/statusline.sh https://raw.githubusercontent.com/fidelisakilan/claude-usage-statusline/main/statusline.sh
chmod +x ~/.claude/statusline.sh
```

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": { "type": "command", "command": "~/.claude/statusline.sh" }
}
```

## Notes

Right alignment reads the terminal width from `/dev/tty`, then `$COLUMNS`. If neither is available, the usage stats sit two spaces after the model name.
