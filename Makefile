# Build meminfo-service Talos system extension with the bldr BuildKit frontend.

BLDR_RELEASE ?= v0.6.5

# toolchain images, keep in sync with the siderolabs/extensions release for the target Talos minor
TOOLS ?= v1.13.0-16-g38b4a6e
TOOLS_PREFIX ?= ghcr.io/siderolabs

REGISTRY ?= cr.v.zyxmasta.net
REPOSITORY ?= talos
PROJECT ?= meminfo-service
IMAGE_GHCR ?= ghcr.io/wu-wu/$(PROJECT)

TAG := $(shell sed -En 's/^VERSION: *"?([^"]+)"?$$/\1/p' vars.yaml)
IMAGE := $(REGISTRY)/$(REPOSITORY)/$(PROJECT):$(TAG)

ARTIFACTS := _out
TARGET := meminfo-service
PLATFORM ?= linux/amd64,linux/arm64
LOCAL_ARCH := $(shell uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
SOURCE_DATE_EPOCH ?= $(shell git log -1 --pretty=%ct 2>/dev/null || echo 0)

BUILD := docker buildx build
BUILD_ARGS = --build-arg=TOOLS=$(TOOLS) \
	--build-arg=TOOLS_PREFIX=$(TOOLS_PREFIX) \
	--build-arg=SOURCE_DATE_EPOCH=$(SOURCE_DATE_EPOCH)
COMMON_ARGS = --file=Pkgfile --target=$(TARGET) \
	--provenance=false --sbom=false $(BUILD_ARGS)

.PHONY: all build artifacts arch-build arch-push push clean

all: build

## build: single-arch (local) image, loaded into the local Docker
build:
	$(BUILD) --load --platform=linux/$(LOCAL_ARCH) $(COMMON_ARGS) --tag=$(IMAGE) .

## artifacts: multi-arch tarballs to $(ARTIFACTS) for inspection/verification
artifacts:
	@mkdir -p $(ARTIFACTS)
	$(BUILD) --platform=linux/amd64 $(COMMON_ARGS) --output=type=docker,dest=$(ARTIFACTS)/meminfo-amd64.tar .
	$(BUILD) --platform=linux/arm64 $(COMMON_ARGS) --output=type=docker,dest=$(ARTIFACTS)/meminfo-arm64.tar .

## arch-build: single-arch image tagged $(OUT_IMAGE), no push (CI validation)
arch-build:
	$(BUILD) --platform=linux/$(ARCH) $(COMMON_ARGS) --tag=$(OUT_IMAGE) .

## arch-push: single-arch image tagged $(OUT_IMAGE) pushed (CI, native runner)
arch-push:
	$(BUILD) --platform=linux/$(ARCH) $(COMMON_ARGS) --tag=$(OUT_IMAGE) --push .

## push: multi-arch image to the private registry (requires docker login $(REGISTRY))
push:
	$(BUILD) --platform=$(PLATFORM) $(COMMON_ARGS) --tag=$(IMAGE) --push .

clean:
	rm -rf $(ARTIFACTS)
