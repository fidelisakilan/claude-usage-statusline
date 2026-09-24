# tokamon

A little pet that lives in your [Claude Code](https://claude.com/claude-code) status line. Its mood tracks your session: it's bouncy when you start, gets `$` eyes as the bill climbs, side-eyes you as your usage limit runs low, and keels over when you hit it. It fidgets while Claude works and falls asleep when you walk away.

**Dark**

![tokamon, dark mode](screenshots/dark.png)

**Light**

![tokamon, light mode](screenshots/light.png)

## Moods

When several apply, the first match wins. The face is coloured by 5-hour usage: green, then yellow at 60%, orange at 75%, red at 90%.

| Face | Mood | When |
|------|------|------|
| `(☓‿‿☓)` | dead | 5h or 7d limit at 100% |
| `(-zz-)` | asleep | idle for 10 minutes |
| `(@▃▃@)` | stuffed | context window 90%+ full |
| `(◔‿‿◔)` | almost free | 5h at 60%+ and it resets within 20 minutes |
| `(╥☁╥ )` | crying | 5h at 90%+ |
| `(ಠ_ಠ )` | grim | 7d at 90%+ |
| `(°▃▃°)` | alarmed | 5h at 75%+ |
| `(ಠ‿‿ಠ) x2` | boss | subagents running (with a count) |
| `($▃▃$)` | whale | session cost $50+ |
| `($‿‿$)` | rich | session cost $10+ |
| `(>▃▃<)` | demolition | 300+ lines removed, more than added |
| `(⌐■_■)` | builder | 500+ lines added |
| `(-__-)` | sleepy | session over 4 hours, or midnight to 6am |
| `(≖__≖)` | bored | 5h at 60%+ |
| `(•‿‿•)` | neutral | 5h at 45%+ |
| `(◕‿‿◕)` | happy | 5h at 15%+ |
| `(ᵔ◡◡ᵔ)` | giddy | 5h under 15% |

While Claude is working, the face animates: it glances around, blinks, and now and then puts on shades. When idle it holds still. On API-key plans without usage limits, context use stands in for 5h usage.

Next to the pet: session cost (estimated at API prices, not what a Pro/Max plan bills), context used, and 5-hour and weekly limit used.

## Install

Requires `jq`.

```sh
curl -o ~/.claude/statusline.sh https://raw.githubusercontent.com/fidelisakilan/tokamon/main/statusline.sh
chmod +x ~/.claude/statusline.sh
```

Add to `~/.claude/settings.json` (merge with any hooks you already have):

```json
{
  "statusLine": { "type": "command", "command": "~/.claude/statusline.sh", "refreshInterval": 1 },
  "hooks": {
    "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "~/.claude/statusline.sh busy" }] }],
    "Stop":             [{ "hooks": [{ "type": "command", "command": "~/.claude/statusline.sh idle" }] }],
    "SubagentStart":    [{ "hooks": [{ "type": "command", "command": "~/.claude/statusline.sh agent-start" }] }],
    "SubagentStop":     [{ "hooks": [{ "type": "command", "command": "~/.claude/statusline.sh agent-stop" }] }]
  }
}
```

The hooks tell tokamon when Claude is working and how many subagents are running. Without them the pet still shows its mood, it just never animates.

## Notes

- `refreshInterval: 1` redraws every second (the fastest Claude Code allows) so the pet can animate and the right-alignment catches up after you resize or zoom. Each run takes about 18ms.
- Right alignment reads the terminal width from `/dev/tty`, then `$COLUMNS`. If neither is available, the stats sit two spaces after the model name.
- Run `./test.sh` to check every mood resolves correctly.
