#!/usr/bin/env zsh

juc() {
  if ! command -v just >/dev/null 2>&1; then
    print "juc: just is not installed"
    return 1
  fi

  if ! command -v fzf >/dev/null 2>&1; then
    print "juc: fzf is not installed"
    return 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    print "juc: jq is not installed"
    return 1
  fi

  local json selected recipe query
  local -a menu_lines fzf_args
  local line name kind default input
  local -a param_lines args words

  query="$*"

  if ! json="$(just --dump --dump-format json 2>/dev/null)"; then
    print "juc: no justfile found in current directory tree"
    return 1
  fi

  menu_lines=("${(@f)$(
    print -r -- "$json" | jq -r '
      def fmt_param($p):
        if $p.kind == "plus" then
          "<" + $p.name + "...>"
        elif $p.kind == "star" then
          "[" + $p.name + "...]"
        elif $p.default == null then
          "<" + $p.name + ">"
        else
          "[" + $p.name + "=" + ($p.default | tostring) + "]"
        end;

      .recipes
      | to_entries
      | map(select(.value.private | not))
      | sort_by(.value.namepath // .key)
      | .[]
      | (.value.namepath // .key) as $recipe
      | (.value.parameters // []) as $params
      | [
          $recipe,
          (
            $recipe +
            (if ($params | length) > 0 then
              " " + ($params | map(fmt_param(.)) | join(" "))
            else
              ""
            end)
          ),
          ((.value.doc // "") | split("\n") | .[0])
        ]
      | @tsv
    '
  )}")

  if (( ${#menu_lines[@]} == 0 )); then
    print "juc: no recipes found"
    return 1
  fi

  if [[ -n "$query" ]]; then
    fzf_args+=(--query "$query")
  fi

  selected="$(
    printf '%s\n' "${menu_lines[@]}" |
      fzf \
        --prompt='just> ' \
        --height=60% \
        --reverse \
        --delimiter=$'\t' \
        --with-nth=2,3 \
        --preview 'just --show {1} 2>/dev/null' \
        --preview-window='right,60%,border-left' \
        --select-1 \
        --exit-0 \
        "${fzf_args[@]}"
  )" || return 0

  recipe="${selected%%$'\t'*}"
  if [[ -z "$recipe" ]]; then
    return 0
  fi

  param_lines=("${(@f)$(
    print -r -- "$json" | jq -r --arg recipe "$recipe" '
      .recipes
      | to_entries
      | map(select((.value.namepath // .key) == $recipe))
      | first
      | (.value.parameters // [])
      | .[]
      | [
          .name,
          .kind,
          (if .default == null then "" else (.default | tostring) end)
        ]
      | @tsv
    '
  )}")

  for line in "${param_lines[@]}"; do
    name="${line%%$'\t'*}"
    line="${line#*$'\t'}"
    kind="${line%%$'\t'*}"
    default="${line#*$'\t'}"

    case "$kind" in
      singular)
        if [[ -n "$default" ]]; then
          read "input?${recipe}: ${name} [default: ${default}] > "
          args+=("${input:-$default}")
        else
          read "input?${recipe}: ${name} (required) > "
          if [[ -z "$input" ]]; then
            print "juc: canceled, required argument '${name}' was empty"
            return 1
          fi
          args+=("$input")
        fi
        ;;

      plus)
        read "input?${recipe}: ${name} (one or more, space-separated) > "
        words=("${(z)input}")
        if (( ${#words[@]} == 0 )); then
          if [[ -n "$default" ]]; then
            words=("${(z)default}")
          else
            print "juc: canceled, required variadic argument '${name}' was empty"
            return 1
          fi
        fi
        args+=("${words[@]}")
        ;;

      star)
        if [[ -n "$default" ]]; then
          read "input?${recipe}: ${name} (optional, space-separated) [default: ${default}] > "
          if [[ -z "$input" ]]; then
            words=("${(z)default}")
          else
            words=("${(z)input}")
          fi
        else
          read "input?${recipe}: ${name} (optional, space-separated) > "
          words=("${(z)input}")
        fi
        if (( ${#words[@]} > 0 )); then
          args+=("${words[@]}")
        fi
        ;;

      *)
        print "juc: unsupported parameter kind '${kind}' for '${name}'"
        return 1
        ;;
    esac
  done

  just "$recipe" "${args[@]}"
}
