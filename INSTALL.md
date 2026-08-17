# Install

The `.claude/` folder is hidden. On macOS Finder press `Cmd+Shift+.` to see it,
on Windows Explorer enable "Hidden items", or just use the terminal below.

## 1. Copy into your repo

    cp -r .claude /path/to/your-go-repo/
    cp -r .github /path/to/your-go-repo/     # optional: CI gate check
    cp install-skills.sh /path/to/your-go-repo/

## 2. Restore executable bits — REQUIRED

Zip archives lose the executable bit on most platforms. A hook without `+x`
does not block anything: it fails open, silently. This is the single most
likely way to end up with a system that looks fine and enforces nothing.

    cd /path/to/your-go-repo
    chmod +x .claude/hooks/*.sh .claude/harness/*.sh install-skills.sh

## 3. Install the third-party skills

    ./install-skills.sh

Read every SKILL.md before you trust it. Bundled scripts run with your agent's
permissions, which on this machine means your kubeconfig and cloud creds.

## 4. Prove the gates work

    .claude/harness/verify-gates.sh

Expect `gates: 20 fixture(s) passed, 0 failure(s)`. Anything else, fix before
running an agent.

## 5. Fill in the two project skills

    .claude/skills/task-routing/SKILL.md
    .claude/skills/platform-runbook/SKILL.md

Both are preloaded into agents on every run — keep each under ~1500 tokens.

## 6. Verify the hook payload shapes

The hooks parse hook input with `jq` and the field names are not guaranteed
across Claude Code versions. Once per hook type, swap in the debug helper:

    command: "${CLAUDE_PROJECT_DIR}/.claude/hooks/_payload-debug.sh pretool-bash"

Trigger the tool, read `/tmp/claude-hook-payload-pretool-bash.json`, correct
the jq paths in the real hook.

## 7. Accept workspace trust

Open Claude Code in the repo and accept the trust prompt. Until you do,
frontmatter hooks from project-level agents are skipped and only logged to the
debug log — the agents run, the gates do not.

## 8. Start

    claude --agent task-composer

Do not enable all eleven agents at once. See the deployment order in
`.claude/README.md`.
