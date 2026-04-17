# claude-code-agent-ops

CLI tools for inspecting Claude Code's local session data -- token usage, tool/skill statistics, and full conversation replay.

Claude Code stores session transcripts as JSONL files in `~/.claude/projects/`. These scripts parse that data to give you visibility into what happened, how many tokens were used, and which tools were called.

## Scripts

### claude-usage

Show daily token usage aggregated across all Claude Code sessions.

```
$ claude-usage

Date            Input     Output   Cache Read  Cache Create  Messages
--------------------------------------------------------------------
2026-03-29     68,103    329,410  316,305,935     3,891,262     1,889
2026-03-30     25,947    132,851  238,426,885    10,826,034       740
2026-04-01      9,305    726,890  727,438,361    10,572,236     5,061
2026-04-02     41,960  2,371,916 1,863,188,031    50,649,909     8,128
--------------------------------------------------------------------
TOTAL          145,315  3,561,067 3,145,359,212    75,939,441    15,818
```

Columns:
- **Input** / **Output** -- non-cached tokens sent and received
- **Cache Read** -- tokens served from prompt cache (typically free or heavily discounted)
- **Cache Create** -- tokens written into prompt cache
- **Messages** -- number of assistant responses (API calls)

### claude-tools

Show tool and slash-command usage across all sessions.

```
$ claude-tools

Slash commands (user-typed):
-----------------------------------
  /exit                    31
  /compact                  3

Skill invocations:
-----------------------------------
  (none found)

Tool usage (all sessions):
-----------------------------------
  Bash                                 5590
  Read                                 3631
  Edit                                 2863
  Grep                                 1215
  Write                                 451
  Agent                                 406

  Total tool calls: 16,879
```

Reports three categories:
- **Slash commands** -- commands you typed (from `~/.claude/history.jsonl`)
- **Skill invocations** -- skills triggered via the Skill tool
- **Tool usage** -- every tool call made by the assistant, including MCP tools

### claude-session

List sessions and replay full conversations with color-coded output.

```
$ claude-session
```

Lists all sessions with created/updated dates, token usage, project name, and first message.

```
$ claude-session 3
```

Replays session #3 with full conversation: user messages, assistant text, thinking blocks, tool calls with arguments, tool results, and per-response token counts.

**Display options:**

| Flag | Effect |
|------|--------|
| `--compact` | Hide thinking blocks, truncate tool results to 3 lines |
| `--no-thinking` | Hide thinking/reasoning blocks only |
| `--no-tools` | Hide tool calls and tool results |
| `-h`, `--help` | Show help |

**Session identifiers:**

| Format | Meaning |
|--------|---------|
| `N` | Session number from the list (e.g. `3`) |
| `<uuid>` | Full or partial session UUID (e.g. `a8359a07`) |
| `<path>` | Direct path to a `.jsonl` file (for subagents) |

A bare number within the session list range is treated as a list index. Larger numbers or strings containing non-digit characters are treated as UUID prefixes. Ambiguous prefixes produce an error listing the matches.

Sessions with subagent conversations are noted in the output.

### claude-ncsl

Report non-comment source lines (NCSL) broken down by language for any project directory.

```
$ claude-ncsl ~/projects/Embedded-Lab-Control

NCSL report: Embedded-Lab-Control
/home/john/projects/Embedded-Lab-Control

  Language     Files      Total     Blank   Comment       NCSL   NCSL%
  ---------------------------------------------------------------
  Python          52     19,014     3,506       523     14,985   78.8%
  HTML             7        796        73        14        709   89.1%
  CSS              1        415        68        18        329   79.3%
  Shell            4        375        60        78        237   63.2%
  JavaScript       1         76        11        10         55   72.4%
  ---------------------------------------------------------------
  TOTAL           65     20,676     3,718       643     16,315   78.9%
```

Columns:
- **Files** -- number of source files for that language
- **Total** -- total lines in those files
- **Blank** -- empty or whitespace-only lines
- **Comment** -- lines that are only comments (lines with both code and comments count as NCSL)
- **NCSL** -- non-comment source lines (Total - Blank - Comment)
- **NCSL%** -- percentage of total lines that are NCSL

**Supported languages:** Python, C, C++, C/C++ headers, JavaScript, TypeScript, Rust, Go, Java, CSS/SCSS/LESS, PHP, Shell, Ruby, Makefile, Lua, HTML, Assembly, Linker scripts.

**Options:**

| Flag | Effect |
|------|--------|
| `-x DIR` | Exclude a directory name (repeatable) |
| `--no-color` | Disable colored output |
| `-h`, `--help` | Show help |

Defaults to the current directory if no path is given. Automatically skips `.git`, `node_modules`, `__pycache__`, `venv`, `build`, `dist`, and other common non-source directories.

## Installation

The scripts are standalone Python 3 files with no dependencies beyond the standard library.

```bash
# Copy to a directory in your PATH
cp claude-usage claude-tools claude-session claude-ncsl ~/Scripts/
chmod +x ~/Scripts/claude-usage ~/Scripts/claude-tools ~/Scripts/claude-session ~/Scripts/claude-ncsl

# Or add this repo's directory to your PATH
echo 'export PATH="$HOME/projects/claude-code-agent-ops:$PATH"' >> ~/.bashrc
```

## How it works

Claude Code writes session transcripts to `~/.claude/projects/<project>/<session-id>.jsonl`. Each line is a JSON object representing one message in the conversation:

- **User messages** -- your prompts and tool results returned to the assistant
- **Assistant messages** -- text, thinking blocks, and tool calls, with a `usage` object containing token counts
- **Metadata** -- timestamps, session IDs, model names, git branch, request IDs

The scripts glob all `.jsonl` files under `~/.claude/projects/` and parse the `usage` fields and `content` blocks. Active sessions are readable in real time -- completed turns appear immediately, while the in-progress response appears once it finishes streaming.

## Requirements

- Python 3.6+
- Claude Code (the session files it generates)

## License

MIT
