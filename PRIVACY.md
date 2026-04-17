# Privacy Policy for ido4specs

**Effective date:** 2026-04-17
**Last updated:** 2026-04-17

`ido4specs` is a Claude Code plugin that runs locally on your machine. This policy explains what data the plugin handles. **The short version: we collect nothing about you, send nothing to any server, and have no analytics or telemetry.**

## What `ido4specs` does NOT do

- We do not collect personal information of any kind
- We do not send telemetry, usage analytics, crash reports, or any other diagnostic signals
- We do not make network requests to any server (`ido4specs`-owned or otherwise)
- We do not share any data with third parties
- We do not have user accounts, login, or authentication
- We do not store any user data on remote servers — there are no remote servers
- We do not track which projects you work in, which skills you invoke, or how often

## What `ido4specs` reads

The plugin operates on files within your local filesystem only. Specifically:

- **Strategic spec files** (`.md` files matching the `-strategic-spec.md` or `-spec.md` naming convention) — only when you explicitly invoke `/ido4specs:create-spec` on a path you provide.
- **Technical canvas / technical spec files** (`.md` files in `specs/` or `docs/specs/`) — only when you invoke the relevant skill (`synthesize-spec`, `validate-spec`, `review-spec`, `refine-spec`) on them.
- **Filenames in `specs/`** — the `SessionStart` hook scans for spec artifact filenames using `ls` globbing. It does **not** read the contents of any file during this scan; it only checks which filenames exist.
- **Your codebase** — when you run `/ido4specs:create-spec`, parallel `Explore` subagents read source files in your project to ground the task decomposition in real code. These reads happen locally on your machine; nothing is transmitted off your machine by `ido4specs`.

All file reads happen on your local machine, in the directory where you launched Claude Code.

## What `ido4specs` writes

- **Technical canvas and technical spec artifacts** (`.md` files) at paths you specify when you invoke skills. Written to your project directory under your control.
- **One empty marker file per project** at `${CLAUDE_PLUGIN_DATA}/welcomed-{hash}` (typically `~/.claude/plugins/data/ido4specs/welcomed-{hash}`). The file is empty — its existence prevents the first-install greeting from repeating in that project. The hash is derived from the SHA-256 of your project's filesystem path, truncated to 16 hex characters; no other identifying information is encoded.
- **Bundled validator binaries** copied from the plugin's `dist/` directory to `${CLAUDE_PLUGIN_DATA}` once per session by the `SessionStart` hook. These are static `.js` files shipped with the plugin (no network fetch).

The plugin does not modify any other files in your project or system.

## Third-party services

`ido4specs` itself does not interact with any third-party service.

The plugin runs inside Claude Code, which is a product of Anthropic. Claude Code uses Anthropic's Claude API to power the AI synthesis steps in `create-spec` and `synthesize-spec`. The information you provide to those skills (your strategic spec text, your codebase contents that the `Explore` subagents surface) is processed by Claude Code's normal model invocations. Anthropic's privacy practices for the Claude API are documented at [anthropic.com/legal/privacy](https://www.anthropic.com/legal/privacy).

`ido4specs` does not add to, modify, or intercept the data path between your Claude Code session and Anthropic's API. We do not receive, log, store, or have any access to data exchanged between your session and the API.

## Data retention

- **Marker file** (`welcomed-{hash}`): persists until you uninstall the plugin or manually delete it. To delete manually: `rm ~/.claude/plugins/data/ido4specs/welcomed-*`. Plugin uninstall deletes the entire data directory automatically.
- **Spec artifacts you produce** (`-tech-canvas.md`, `-tech-spec.md`): persist in your project directory until you delete them. They belong to you and remain under your control. The plugin never reads them again unless you explicitly invoke a skill on them.
- **No remote data**: there is no remote storage, so there is no data on any server to retain, access, or delete.

## Your rights

Because `ido4specs` collects no personal data, the rights typically conferred by privacy laws like GDPR and CCPA (access, deletion, portability, correction, etc.) are satisfied trivially — there is nothing on our end to access, delete, port, or correct.

To stop using the plugin entirely:
- **Disable for a project**: add `"ido4specs@ido4-plugins": false` to `enabledPlugins` in `.claude/settings.json` (project) or `~/.claude/settings.json` (global)
- **Uninstall**: run `/plugin uninstall ido4specs@ido4-plugins`. This removes the plugin and its data directory.

## Children's privacy

`ido4specs` is a developer tool. It does not target or knowingly collect data from children, and operates in environments not generally accessible to children.

## Security

Per the project's [SECURITY.md](SECURITY.md), the plugin's hook surface is limited to read-only filename scans and writes to its own plugin data directory. The bundled validators are checksummed (SHA-256, recorded in `dist/.tech-spec-format-checksum` and `dist/.spec-format-checksum`) and version-marked. Any tampering with the bundled validators is detectable by `/ido4specs:doctor`.

## Changes to this policy

Substantive changes will be reflected in this file with an updated date and called out in the project's [CHANGELOG.md](CHANGELOG.md). The current version of this policy is always available at [github.com/ido4-dev/ido4specs/blob/main/PRIVACY.md](https://github.com/ido4-dev/ido4specs/blob/main/PRIVACY.md).

## Contact

Questions about this policy: **coman2904@gmail.com**, or open an issue at [github.com/ido4-dev/ido4specs/issues](https://github.com/ido4-dev/ido4specs/issues).
