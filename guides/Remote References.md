# Remote References

Apical supports `$ref` to external URLs by resolving them from a local cache.
This approach ensures reproducible builds and avoids network requests during
compilation.

## Overview

OpenAPI allows referencing external schemas:

```yaml
paths:
  "/users":
    post:
      requestBody:
        content:
          "application/json":
            schema:
              $ref: "https://example.com/schemas/user.json#/definitions/User"
```

Apical resolves these references from a local cache directory rather than
fetching them at compile time.

## Setup

### 1. Configure the Cache Directory

```elixir
Apical.router_from_file("api.yaml",
  controller: MyController,
  remote_refs_cache: "priv/openapi_cache"
)
```

### 2. Populate the Cache

Download the remote schemas before compilation:

```bash
# Create directory structure matching the URL
mkdir -p priv/openapi_cache/example.com/schemas

# Download the schema
curl -o priv/openapi_cache/example.com/schemas/user.json \
     https://example.com/schemas/user.json
```

### 3. Add Cache to Version Control

Commit the cache directory to ensure reproducible builds:

```bash
git add priv/openapi_cache/
```

## URL to Path Mapping

Remote URLs are mapped to cache paths by removing the scheme and preserving
the host and path:

| URL | Cache Path |
|-----|------------|
| `https://example.com/schemas/user.json` | `cache/example.com/schemas/user.json` |
| `https://api.example.com/v1/types.yaml` | `cache/api.example.com/v1/types.yaml` |

## Fragment Resolution

URL fragments point to specific locations within the cached document:

```yaml
$ref: "https://example.com/schemas/user.json#/definitions/User"
```

Apical will:
1. Load `cache/example.com/schemas/user.json`
2. Resolve the JSON pointer `/definitions/User`
3. Inline the resolved content

## File Formats

The cache supports both JSON and YAML files:

- `.json` files are parsed as JSON
- `.yaml` and `.yml` files are parsed as YAML
- Other extensions: JSON parsing is attempted first, then YAML

## Error Messages

### Missing Cache Configuration

```
Remote ref encountered but no cache configured.

Found remote $ref: https://example.com/schemas/user.json
At path: ["paths", "/users", "post", "requestBody", ...]

To use remote refs, configure the cache directory:

    Apical.router_from_string(schema,
      remote_refs_cache: "priv/openapi_cache"
    )
```

### Missing Cached File

```
Remote ref not found in cache.

URL: https://example.com/schemas/user.json
Expected cache path: priv/openapi_cache/example.com/schemas/user.json
At schema path: ["paths", "/users", "post", ...]

To fix, download the schema to the cache:

    mkdir -p priv/openapi_cache/example.com/schemas
    curl -o priv/openapi_cache/example.com/schemas/user.json \
         https://example.com/schemas/user.json
```

### Invalid Fragment

```
Could not resolve fragment in remote ref.

Ref: https://example.com/schemas/user.json#/definitions/User
Fragment: #/definitions/User
Cache path: priv/openapi_cache/example.com/schemas/user.json

The fragment pointer does not exist in the cached document.
```

## Example Project Structure

```
my_app/
  lib/
  priv/
    openapi/
      api.yaml              # Your OpenAPI document
    openapi_cache/
      example.com/
        schemas/
          user.json         # Cached remote schema
          common.json
      other-api.com/
        v1/
          types.yaml
  mix.exs
```

## Security Benefits

Using a local cache provides several security advantages:

1. **No network during compilation** - Prevents supply chain attacks via
   compromised remote schemas
2. **Reproducible builds** - Same schema content across all builds
3. **Audit trail** - Cached schemas are version controlled
4. **Offline development** - No internet required for compilation

## Updating Cached Schemas

When remote schemas change, manually update your cache:

```bash
# Update a specific schema
curl -o priv/openapi_cache/example.com/schemas/user.json \
     https://example.com/schemas/user.json

# Commit the update
git add priv/openapi_cache/
git commit -m "Update cached user schema"
```

Consider using a script or CI job to check for schema updates and notify
developers.
