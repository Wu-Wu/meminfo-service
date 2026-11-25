# meminfo-service

Talos Linux system extension: runs a small HTTP server as an extension service
(`ext-meminfo`) that reports node memory usage as JSON from `/proc/meminfo`.

```bash
$ curl http://<node-ip>:1027/meminfo
{"total":33552644096,"avail":29835171840,"used":3717472256}
```

The service is managed by Talos init and appears in the services list with the
`ext-` prefix: `talosctl service ext-meminfo`, logs via
`talosctl logs ext-meminfo`.

Images: `ghcr.io/wu-wu/meminfo-service:<version>` (multi-arch amd64/arm64).
This is a system extension image, not an OS image: it is passed to the Talos
installer build via `--system-extension-image`.

## Build

The image is a Talos system extension built with the [bldr](https://github.com/siderolabs/bldr)
BuildKit frontend (`Pkgfile` + `pkg.yaml`). Requires Docker with buildx.
Local builds need no registry access (beyond the public base images on ghcr):

```bash
make build      # single-arch (local) image, loaded into local Docker
make artifacts  # _out/meminfo-{amd64,arm64}.tar for inspection
make push REGISTRY=<your-registry>   # multi-arch build + push (requires docker login)
```

`TAG` is taken from `VERSION` in `vars.yaml`; toolchain images (`TOOLS`,
`TOOLS_PREFIX`) are pinned in the Makefile to the siderolabs/extensions
release for the current Talos minor.

## Release

1. bump `VERSION` in `vars.yaml`,
2. `git tag <VERSION> && git push --tags`,
3. the release workflow (`.github/workflows/release.yml`) builds both
   architectures on native runners, publishes per-arch images to
   `ghcr.io/wu-wu/meminfo-service`, composes the `<VERSION>`/`latest`
   multi-arch manifests and opens a GitHub release.

CI setup (once per repo): variables `PVTHUB_HOSTNAME`/`PVTHUB_USERNAME` and
secret `PVTHUB_PASSWORD` enable an additional best-effort mirror of the
multi-arch manifests to a private registry behind
[cesanta/docker_auth](https://github.com/cesanta/docker_auth) (the CI account
needs a `pull,push` ACL for this image only). PRs build without publishing.

## Layout

```
Pkgfile                 bldr BuildKit frontend entry
pkg.yaml                extension build steps (Go binary + service definition)
manifest.yaml.tmpl      extension metadata, rendered with vars.yaml
vars.yaml               VERSION, TIER
meminfo.yaml            Talos extension service definition
internal/base/pkg.yaml  build environment (siderolabs tools image, validator)
src/                    Go source
```

## License

MIT
