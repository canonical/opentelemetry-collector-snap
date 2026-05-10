set allow-duplicate-recipes
set allow-duplicate-variables
import? 'snaps.just'

[private]
@default:
  just --list
  echo ""
  echo "For help with a specific recipe, run: just --usage <recipe>"

# Generate a snap for the latest version of the upstream project
[arg("source_repo", help="Repository of the upstream project in 'org/repo' form")]
[group("maintenance")]
update source_repo:
  #!/usr/bin/env bash
  set -e
  just --justfile snaps.just update {{source_repo}}
  # Additional update steps
  latest_release="$(gh release list --repo {{source_repo}} --exclude-pre-releases --limit=1 --json tagName --jq '.[0].tagName')"
  full_version="${latest_release#v}"
  version="$(echo "$full_version" | grep -oP '^\d+\.\d+')"
  snapcraft_file="./$version/snap/snapcraft.yaml"
  # Get old version from the copied snapcraft.yaml (source-tag still has the previous value)
  old_source_tag="$(yq '.parts.ocb["source-tag"]' "$snapcraft_file")"
  old_full_version="${old_source_tag#v}"
  # Update the source-tag
  full_version="$full_version" yq -i \
    '.parts.ocb["source-tag"] = "v" + strenv(full_version)' \
    "$snapcraft_file"
  # Update the wget URLs in the override-build script
  sed -i "s|/$old_full_version/|/$full_version/|g" "$snapcraft_file"
  echo "✓ Updated version references in $snapcraft_file"
