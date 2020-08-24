#-------------------------------------------------------------------------------
# Global variables.

GO=go
EXEC=gh-md-toc
BUILD_DIR=build
BUILD_OS="windows darwin freebsd linux"
BUILD_ARCH="amd64 386"

#-------------------------------------------------------------------------------
# Running `make` will show the list of subcommands that will run.

all: help

.PHONY: help
## help: prints this help message
help:
	@echo "Usage: \n"
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' | sed -e 's/^/ /'

#-------------------------------------------------------------------------------
# Clean

.PHONY: clean-go-deep
## clean-go-deep: [clean] deep-clean Go's module cache
clean-go-deep:
	$(GO) clean -i -r -x -testcache -modcache -cache

.PHONY: clean-go
## clean-go: [clean] regular cleaning of the Go build
clean-go:
	rm -f ${EXEC}
	rm -f ${BUILD_DIR}/*
	$(GO) clean

.PHONY: clean
## clean: [clean] runs ALL standard cleaning tasks
clean: clean-go

#-------------------------------------------------------------------------------
# Compile

.PHONY: build-prep
## build-prep: [build] updates go.mod and downloads dependencies
build-prep:
	$(GO) mod tidy -v && \
	$(GO) mod download -x && \
	$(GO) get -u=patch -v ./...

.PHONY: build-release-prep
## build-release-prep: [build] post-development, ready to release steps
build-release-prep:
	$(GO) mod download

.PHONY: build
## build: [build] compiles the source code into a native binary
build: clean build-prep
	$(GO) build -ldflags="-s -w -X main.commit=$$(git rev-parse HEAD) -X main.date=$$(date -I)" -i -o ${EXEC}

.PHONY: install
## install: [build] installs the command to ~/.bin/, which should be on your PATH
install:
	mkdir -p ~/bin
	cp -fv ${EXEC} ~/bin/${EXEC}

.PHONY: new-golang
## new-golang: [build] installs a non-standard/future version of Golang
new-golang:
	go get golang.org/dl/$(GO) && \
	$(GO) download

#-------------------------------------------------------------------------------
# Testing

test: clean
	$(GO) test -cover -o ${EXEC}

#-------------------------------------------------------------------------------
# Linting

.PHONY: golint
## golint: [lint] runs `golangci-lint` (static analysis, formatting) against all Golang (*.go) tests with a standardized set of rules
golint:
	@ echo " "
	@ echo "=====> Running gofmt and golangci-lint..."
	cd ./src && gofmt -s -w *.go
	cd ./src && golangci-lint run --fix *.go

.PHONY: markdownlint
## markdownlint: [lint] runs `markdownlint` (formatting, spelling) against all Markdown (*.md) documents with a standardized set of rules
markdownlint:
	@ echo " "
	@ echo "=====> Running Markdownlint..."
	npx markdownlint-cli --fix '*.md' --ignore 'node_modules'

.PHONY: lint
## lint: [lint] runs ALL linting/validation tasks
lint: markdownlint golint

#-------------------------------------------------------------------------------
# Git Tasks

.PHONY: tag
## tag: [release] tags (and GPG-signs) the release
tag:
	@ if [ $$(git status -s -uall | wc -l) != 1 ]; then echo 'ERROR: Git workspace must be clean.'; exit 1; fi;

	@echo "This release will be tagged as: $$(cat ./VERSION)"
	@echo "This version should match your release. If it doesn't, re-run 'make version'."
	@echo "---------------------------------------------------------------------"
	@read -p "Press any key to continue, or press Control+C to cancel. " x;

	@echo " "
	@chag update $$(cat ./VERSION)
	@echo " "

	@echo "These are the contents of the CHANGELOG for this release. Are these correct?"
	@echo "---------------------------------------------------------------------"
	@chag contents
	@echo "---------------------------------------------------------------------"
	@echo "Are these release notes correct? If not, cancel and update CHANGELOG.md."
	@read -p "Press any key to continue, or press Control+C to cancel. " x;

	@echo " "

	git add .
	git commit -a -m "Preparing the $$(cat ./VERSION) release."
	chag tag --sign

.PHONY: version
## version: [release] sets the version for the next release; pre-req for a release tag
version:
	@echo "Current version: $$(cat ./VERSION)"
	@read -p "Enter new version number: " nv; \
	printf "$$nv" > ./VERSION

.PHONY: snapshot
## snapshot: [release] compiles the source code into binaries for all supported platforms
snapshot:
	goreleaser release --rm-dist --skip-publish --snapshot

.PHONY: release
## release: [release] compiles the source code into binaries for all supported platforms and prepares release artifacts
release:
	goreleaser release --rm-dist --skip-publish
	mv -vf dist/gh-md-toc.rb Formula/gh-md-toc.rb
	sha256sum ./dist/gh-md-toc.zip
