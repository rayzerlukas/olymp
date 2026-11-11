# olymp

A [community app store](https://github.com/getumbrel/umbrel-community-app-store) for
[umbrelOS](https://umbrel.com) with the owner's self-hosted apps. This repository holds
only app manifests and compose files. The apps' code and images are built in their own
private repositories, and secrets never live here.

| App | What it does |
|---|---|
| [athena](olymp-athena/umbrel-app.yml) (`olymp-athena`) | Study tracker: makes course material from ILIAS searchable for Claude (MCP connector), Telegram bot for deadlines, status page |

## Add the store to umbrelOS

1. Open the **App Store** in umbrelOS.
2. Click **⋯** (top right) → **Community App Stores**.
3. Paste `https://github.com/rayzerlukas/olymp` and click **Add**.
4. Open the store **olymp** and install an app.

## Images

The images are built from private repositories (for example `ghcr.io/rayzerlukas/athena`).
Each compose file pins its images as `tag@sha256:<digest>`. A release of an app opens a pull
request here with the new version and digest.

> **Open:** how umbrelOS pulls a private GHCR image. Either the package is made public, or
> the Umbrel logs in to GHCR once (`docker login ghcr.io`) and umbrelOS uses that login.
> This needs a test on the device.

## athena: first start

athena stores everything under the app's data directory
(`~/umbrel/app-data/olymp-athena/data/`):

| Folder | Content |
|---|---|
| `postgres/` | database |
| `files/` | downloads from ILIAS |
| `backups/` | daily `pg_dump` backups, rotated (7 daily, 5 weekly) |
| `config/` | `athena.env` (secrets) and `semesters/*.yaml` |

1. Install the app; it starts without secrets and reports what is missing.
2. Create `config/athena.env` (readable only by you, `chmod 600`) with the secrets: ILIAS
   login, connector token, Telegram bot token. All settings: athena's configuration docs
   (`docs/athena/configuration.md` in the athena repository).
3. Put your semester file into `config/semesters/` (format: athena's
   `docs/athena/semester-files.md`).
4. Restart the app in umbrelOS. The status page opens from the app icon, behind the
   Umbrel login.

Until athena's web app can edit settings and semester files (planned), steps 2 and 3 need
SSH or the Files app.

## athena: connector for Claude (open)

The MCP connector (service `mcp`, port 8080 inside the app) must be reachable from
Anthropic's cloud. Not decided yet; both options need a test on the device:

- **TODO, option 1:** through `app_proxy` with `PROXY_AUTH_WHITELIST: "/mcp*"` (the
  connector's bearer token protects it; everything else stays behind the Umbrel login),
  made public with Tailscale Funnel.
- **TODO, option 2:** a raw port for the connector (`ports:` with an explicit host port),
  made public with Tailscale Funnel.

## Development

```bash
sh scripts/validate.sh          # app ids, manifests, compose config, secret scan
pipx run yamllint --strict .    # YAML lint
```

CI runs both on every pull request. Rules for this repository:

- App folders are named after the app id and start with `olymp-`.
- Images are pinned by digest; no `build:`.
- Nothing personal or secret: no tokens, email addresses, host or tailnet names, chat ids.
