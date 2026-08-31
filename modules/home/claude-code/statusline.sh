#!/usr/bin/env bash
# Claude Code statusLine command.
# Mirrors the Starship prompt: directory · git branch+status · nix_shell · model · context.
# Read by modules/home/claude-code.nix — edit here, run `make switch`.

input=$(cat)

# --- directory (truncate to 3 segments, repo-relative when inside a git repo) ---
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
git_root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)
if [ -n "$git_root" ]; then
  rel="${cwd#"$git_root"/}"
  [ "$rel" = "$cwd" ] && rel="" # cwd IS the root
  repo_name=$(basename "$git_root")
  if [ -z "$rel" ]; then
    dir_display="$repo_name"
  else
    # keep up to 3 trailing path segments
    truncated=$(echo "$rel" | awk -F/ '{
      n=NF; start=(n>2)?n-2:1;
      for(i=start;i<=n;i++) { printf "%s", $i; if(i<n) printf "/" }
    }')
    dir_display="$repo_name/$truncated"
  fi
else
  # outside git: show up to 3 path segments
  dir_display=$(echo "$cwd" | awk -F/ '{
    n=NF; start=(n>3)?n-2:1;
    for(i=start;i<=n;i++) { printf "%s", $i; if(i<n) printf "/" }
  }')
fi

# --- git branch + status ---
git_info=""
if [ -n "$git_root" ]; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null ||
    git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    status_flags=$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)
    modified=$(echo "$status_flags" | grep -c '^ M\| M' 2>/dev/null || true)
    untracked=$(echo "$status_flags" | grep -c '^??' 2>/dev/null || true)
    staged=$(echo "$status_flags" | grep -c '^[MADRC]' 2>/dev/null || true)
    flags=""
    [ "$staged" -gt 0 ] && flags="${flags}+"
    [ "$modified" -gt 0 ] && flags="${flags}!"
    [ "$untracked" -gt 0 ] && flags="${flags}?"
    if [ -n "$flags" ]; then
      git_info=" [$branch $flags]"
    else
      git_info=" [$branch]"
    fi
  fi
fi

# --- nix shell indicator ---
nix_info=""
if [ -n "$IN_NIX_SHELL" ] || [ -n "$NIX_BUILD_TOP" ]; then
  nix_info=" ❄ nix"
fi

# --- model ---
model=$(echo "$input" | jq -r '.model.display_name // .model.id // ""')

# --- context remaining ---
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
ctx_info=""
if [ -n "$remaining" ]; then
  ctx_info=" ctx:$(printf '%.0f' "$remaining")%%"
fi

# --- rate limits ---
rate_info=""
five=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
if [ -n "$five" ]; then
  rate_info=" 5h:$(printf '%.0f' "$five")%%"
fi

# --- assemble with ANSI colours (will be dimmed by Claude Code) ---
printf '\033[34m%s\033[0m\033[33m%s\033[0m\033[36m%s\033[0m \033[35m%s\033[0m\033[32m%s\033[0m%s' \
  "$dir_display" \
  "$git_info" \
  "$nix_info" \
  "$model" \
  "$ctx_info" \
  "$rate_info"
