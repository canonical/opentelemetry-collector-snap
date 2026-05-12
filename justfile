set allow-duplicate-recipes
set allow-duplicate-variables
import? 'snaps.just'

[private]
@default:
  just --list
  echo ""
  echo "For help with a specific recipe, run: just --usage <recipe>"

# Update the snap to the latest upstream version (otelcol-specific: filters release tags)
[arg("source_repo", help="Repository of the upstream project in 'org/repo' form")]
[group("maintenance")]
update source_repo:
  #!/usr/bin/env bash
  set -e

  # otelcol-releases publishes multiple components (cmd/builder, cmd/opampsupervisor, …)
  # under their own tags. Filter to only the collector release tags (v<digits>…).
  latest_release="$(gh release list --repo {{source_repo}} --exclude-pre-releases --limit=20 --json tagName --jq '[.[] | select(.tagName | test("^v\\d"))][0].tagName')"
  echo "Latest release for {{source_repo}} is $latest_release"

  # Parse full semver (X.Y.Z) and major.minor (X.Y)
  full_version="${latest_release#v}"
  major_minor="$(echo "$full_version" | grep -oP '^\d+\.\d+')"
  if [[ -z "$major_minor" ]]; then
    echo "× Error: could not parse version from '$latest_release'"
    exit 1
  fi

  # Get current version from latest/ folder
  if [[ ! -f "latest/snap/snapcraft.yaml" ]]; then
    echo "× Error: latest/snap/snapcraft.yaml not found"
    exit 1
  fi
  current_version="$(yq -r '.version' latest/snap/snapcraft.yaml)"

  # Compare versions using sort -V (version sort)
  newer_version="$(printf '%s\n%s' "$current_version" "$full_version" | sort -V | tail -n1)"
  if [[ "$newer_version" == "$current_version" && "$full_version" != "$current_version" ]]; then
    echo "Current version ($current_version) is newer than or equal to upstream ($full_version), nothing to do"
    exit 0
  fi
  if [[ "$full_version" == "$current_version" ]]; then
    echo "Already at version $full_version, nothing to do"
    exit 0
  fi

  updated_folders=""

  # Update the latest/ folder
  echo "Updating latest/ folder to version $full_version ..."
  snapcraft_file="latest/snap/snapcraft.yaml"
  old_source_tag="$(yq '.parts.ocb["source-tag"]' "$snapcraft_file")"
  old_full_version="${old_source_tag#v}"

  full_version="$full_version" yq -i '.version = strenv(full_version)' "$snapcraft_file"
  full_version="$full_version" yq -i '.parts.ocb["source-tag"] = "v" + strenv(full_version)' "$snapcraft_file"
  sed -i "s|/$old_full_version/|/$full_version/|g" "$snapcraft_file"
  updated_folders="latest"
  echo "✓ Updated latest/ to $full_version"

  # Update the X.Y/ folder if it exists (no auto-creation per ADR)
  if [[ -d "$major_minor" ]]; then
    echo "Updating $major_minor/ folder to version $full_version ..."
    snapcraft_file="$major_minor/snap/snapcraft.yaml"
    old_source_tag="$(yq '.parts.ocb["source-tag"]' "$snapcraft_file")"
    old_full_version="${old_source_tag#v}"

    full_version="$full_version" yq -i '.version = strenv(full_version)' "$snapcraft_file"
    full_version="$full_version" yq -i '.parts.ocb["source-tag"] = "v" + strenv(full_version)' "$snapcraft_file"
    sed -i "s|/$old_full_version/|/$full_version/|g" "$snapcraft_file"
    updated_folders="$updated_folders $major_minor"
    echo "✓ Updated $major_minor/ to $full_version"
  else
    echo "No $major_minor/ folder exists, skipping track-specific update"
  fi

  echo "updated_folders=$updated_folders"
  echo "new_version=$full_version"
