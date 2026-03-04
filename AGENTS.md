# Repository Guidelines

## Project Structure & Module Organization
This repository is an Emacs setup rooted at `~/.emacs.d`.

- `init.el`, `early-init.el`: startup entry points.
- `lisp/`: main modules (`core-bootstrap.el`, `ui-config.el`, `editing-config.el`, `tools-config.el`, `ai-suite.el`).
- `base/`: shared keymaps (`keybindings.el`).
- `themes/`: custom themes.
- `tree-sitter/`: local grammar binaries (`libtree-sitter-*.so`).
- `var/`: generated runtime state (cache, elpa, straight, tmp).

Add new features in `lisp/` and require them from `init.el` in dependency-safe order.

## Build, Test, and Development Commands
- `emacs`: start Emacs with this config from repo root.
- `emacs --batch -Q --eval "(setq user-emacs-directory default-directory)" -l init.el`: startup smoke test.
- `emacs --batch -Q --eval "(setq user-emacs-directory default-directory)" -f batch-byte-compile lisp/*.el base/*.el`: byte-compile local modules.

If package bootstrap runs on first load, rerun checks after install completes.

## Coding Style & Naming Conventions
- Follow Emacs Lisp defaults: 2-space indentation, kebab-case symbols, concise docstrings.
- Keep module headers (`-*- lexical-binding: t; -*-`) and terminating `(provide 'module-name)`.
- Use `cursor-ai--` for private helpers; reserve `cursor-ai/` for interactive/public entry points.
- Comment only non-obvious logic (fallbacks, package ordering, side effects).

## Testing Guidelines
There is no dedicated in-repo ERT suite yet. Minimum validation:

1. Run the batch startup smoke test.
2. Byte-compile touched modules.
3. Manually verify impacted behavior in Emacs (keybindings, LSP, Dirvish, Org, AI flows).

## Commit & Pull Request Guidelines
History trends toward short, imperative subjects and mostly Conventional Commits (`feat: ...`).

- Preferred format: `type: concise summary` (`feat`, `fix`, `refactor`, `docs`, `chore`).
- Keep each commit focused on one logical change.
- PRs should include scope, changed modules (example: `lisp/tools-config.el`), and verification steps.
- Include screenshots/GIFs for visual changes and link related issues when available.

## Security & Configuration Tips
- Never commit API keys or personal data.
- Configure OpenAI credentials via `OPENAI_API_KEY` or `auth-source` (`lisp/ai-suite.el`).
- Keep generated/runtime files in ignored paths (`var/`, caches, compiled artifacts).
