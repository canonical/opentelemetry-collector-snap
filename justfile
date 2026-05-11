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
  # otelcol-releases publishes multiple components (cmd/builder, cmd/opampsupervisor, …)
  # under their own tags. Filter to only the collector release tags (v<digits>…).
  latest_release="$(gh release list --repo {{source_repo}} --exclude-pre-releases --limit=20 --json tagName --jq '[.[] | select(.tagName | test("^v\\d"))][0].tagName')"
  echo "Latest release for {{source_repo}} is $latest_release"
  full_version="${latest_release#v}"
  version="$(echo "$full_version" | grep -oP '^\d+\.\d+')"
  if [[ -z "$version" ]]; then
    echo "× Error: could not parse major.minor version from '$latest_release'"
    exit 1
  fi
  # If the version already exists, exit here
  if [[ -d "$version" ]]; then echo "Folder $version already exists, nothing to do" && exit 0; fi
  # Create the folder for the new version
  latest_version="$(just --justfile snaps.just latest-version)"
  cp -r "$latest_version" "$version"
  version="$version" yq -i \
    '.version = strenv(version)' \
    "./$version/snap/snapcraft.yaml"
  echo "✓ Created snap for version $version"
  # Additional update steps
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
