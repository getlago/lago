# Lago

Lago is an open-source Stripe Billing alternative.

This library will allow you to build an entire billing logic from scratch, even the most complex one. Lago is a real-time event-based library made for usage-based billing, subscription-based billing, and all the nuances of pricing in between.

## Current Releases

| Project        | Release Badge                                                                                                                       |
| -------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| **Lago**       | [![Lago Release](https://img.shields.io/github/v/release/getlago/lago)](https://github.com/getlago/lago/releases)                   |
| **Lago front** | [![Lago front Release](https://img.shields.io/github/v/release/getlago/lago-front)](https://github.com/getlago/lago-front/releases) |

## Documentation

The official Lago documentation is available here : https://docs.getlago.com

## Contributing

The contribution documentation is available [here](https://github.com/getlago/lago-front/blob/main/CONTRIBUTING.md)

## Front Development Environment

Check the wiki [guide](https://github.com/getlago/lago-front/wiki)

## AI-Assisted Development Skills

This project includes a set of custom skills for Claude Code that automate common migration and testing workflows. Skills are invoked via slash commands.

| Skill                          | Command                              | Description                                                                                                                                                                                                |
| ------------------------------ | ------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Make Tests**                 | `/make-tests <pr-number \| branch>`  | Detects modified component files from a PR or branch, adds `data-test` attributes, and creates or migrates tests following project testing conventions.                                                    |
| **Migrate Dialog**             | `/migrate-dialog <path>`             | Migrates a dialog component from the legacy imperative ref-based `Dialog` system (`forwardRef` + `useImperativeHandle`) to the new hook-based NiceModal system (`useFormDialog` / `useCentralizedDialog`). |
| **Migrate Formik to TanStack** | `/migrate-formik-to-tanstack <path>` | Migrates a React form from Formik (`useFormik` + Yup) to TanStack Form (`useAppForm` + Zod), following project conventions.                                                                                |

### Skill files

Skills live in `.agents/skills/<skill-name>/SKILL.md`. `.claude/skills` symlinks to `.agents/skills`.

## Running Multiple Frontends in Parallel

The `lago-worktree` script lets you run isolated frontend instances side-by-side using git worktrees. Each worktree gets its own branch, Docker container, and port — only the **front** (and optionally the **API**) run in a separate container, while everything else (database, Redis, Redpanda, PDF service, etc.) is shared with the main stack.

This is especially useful for **AI-assisted development**: you can spin up parallel worktrees and let multiple Claude Code agents work on different tickets simultaneously, each in its own isolated environment other then the main branch.

### Setup

Add an alias to your shell config (`~/.zshrc`, `~/.bashrc`, etc.):

```bash
export LAGO_PATH=/Users/<PATH_TO>/lago
alias lago-worktree="$LAGO_PATH/front/scripts/lago-worktree.sh"
```

Then reload your shell (`source ~/.zshrc`) or open a new terminal.

### Prerequisites

- The main Lago stack must be running (`lago up -d`)
- Docker and `pnpm` installed

### Quick Start

```bash
# Create a worktree and start it (front only, shares the main API)
lago-worktree create LAGO-0001

# Create a worktree with a dedicated API container too
lago-worktree create LAGO-0001 --from-api=main

# Branch off a specific front branch instead of main
lago-worktree create LAGO-0001 --from-front=feat/ui

# Both custom bases
lago-worktree create LAGO-0001 --from-front=feat/ui --from-api=feat/endpoint
```

### Commands

| Command                                                     | Description                                          |
| ----------------------------------------------------------- | ---------------------------------------------------- |
| `create <branch> [--from-front=<base>] [--from-api=<base>]` | Create worktree(s) and start containers              |
| `up <name>`                                                 | Start an existing (stopped) worktree                 |
| `down <name>`                                               | Stop containers and free the port                    |
| `destroy <name>`                                            | Stop containers **and delete** the worktree + branch |
| `ps`                                                        | List all worktree instances with status and ports    |

### How It Works

- **Front ports** are auto-assigned and auto-incremented starting from `3001` (`3001`, `3002`, `3003`, ...).
- **API ports** (when using `--from-api`) are auto-assigned and auto-incremented starting from `4001` (`4001`, `4002`, `4003`, ...).
- Each worktree container joins the shared `lago_dev_default` Docker network, so it can reach the database, Redis, and other services from the main stack.
- Without `--from-api`, the front proxies API calls to the shared main API on port `3000`.

### Example Workflow

```bash
# 1. Start working on a ticket
lago-worktree create LAGO-1234

# 2. Open http://localhost:3001 in the browser

# 3. Check running instances
lago-worktree ps

# 4. Stop when done for the day
lago-worktree down LAGO-1234

# 5. Resume later
lago-worktree up LAGO-1234

# 6. No longer needed or merged into main — clean up everything
lago-worktree destroy LAGO-1234
```

## License

Lago is open-source under the GNU Affero General Public License Version 3 (AGPLv3) or any later version.
