# Documentation

Pushes to the `master` branch automatically generate documentation. This isn't done via
a GitHub action, but rather uses a webhook to kick off a build job on the server
where the website is hosted.


# Build and Release

rtk uses the term "API version" to refer to the major component of a version tag.  For
example, the API version for `2.1.0` is `2`.  This is an API compatibility contract:
builds with the same major version component are guaranteed to be compatible with scripts
written against prior builds of that API version.  APIs within a major version may be
extended, but existing code won't break. When breaking API changes are introduced, the
major version is incremented and a new API version is born.

There are two GitHub Workflows for the build and release process:

1. **Build**: Pushing version tags (e.g. `1.0.5`) triggers a workflow to build artifacts
for distribution, and pushes those to the `dist` branch.  The most recent build for each
API version is stored in HEAD of the `dist` branch.

2. **Release**: When a tag in the form `release/YYYYMMDDTHHMMSS` is made against the
`dist` branch, this triggers another workflow that creates a ReaPack XML from the contents
of the tagged branch, and pushes it to `site` for official release.  As with doc
generation, pushes to the `site` branch fire a webhook that causes the webserver to
pull the refreshed ReaPack contents and publish it.

It's possible for the **build** stage to automatically kick off the **release** workflow:
when the tag created in step 1 is for the most current API version, the build workflow
automatically generates a `release/YYYYMMDDTHHMMSS` tag after committing the build
artifacts to the `dist` branch.  This in turn launches the release workflow.

In other words, version tags that apply to the latest API version are automatically
released to users.  Tagging older major versions (e.g. for critical bug fixes) will build
and push to `dist` but won't automatically release.  A release can be created that includes
the new build for the old API version by one of two methods:
  1. Subsequently pushing a version tag under the latest API version
  2. Manually creating and pushing a `release/YYYYMMDDTHHMMSS` tag against the `dist` branch.


## Build

The Build workflow is run when a tag is pushed that starts with `[0-9]`.  Its purpose is to assemble
all artifacts needed for distribution to users.  The `dist` repository holds these artifacts and
the ReaPack created in the Release workflow uses GitHub to serve these files directly.

* Build job
    * Tag is checked out
    * API version is parsed from tag (e.g. `2`)
    * `rtk.lua` is built (using the custom `luaknit` tool) and stored as `build/dist/<major>/rtk.lua`
    * The relevant fragment from `CHANGELOG.md` for the tagged version is pulled and written
      as `build/dist/<major>/CHANGELOG.md`.  This is used by the Release workflow when generating
      the ReaPack XML.
    * These artifacts under `build/dist` are uploaded
* Dist job
    * The `dist` branch is checked out
    * Artifacts from the build job are downloaded
    * The `MANIFEST` file in the `dist` branch is updated to include the new tag. The previous
      tag for the same API version is removed.
    * The files generated in the build job are committed and pushed back to the `dist` branch.
    * If the tagged version is within the most current API version, then a release tag is
      created against the `dist` branch in the form `release/YYYYMMDDTHHMMSS` (which is based
      on the time of the job execution, not the timestamp of the triggering commit).  The new
      tag is then pushed.
      * Note: this action uses a GitHub deploy key (stored in a secret variable) because git pushes
        authenticated via `${{secrets.GITHUB_TOKEN}}` cannot trigger downstream workflows.  (See
        discussion [here](https://github.community/t/github-actions-workflow-not-triggering-with-tag-push/17053/).
        Presumably this is a safety mechanism to avoid infinite loops.)


## Release

The Release workflow is run when a tag in the form `release/YYYYMMDDTHHMMSS` is pushed
against the `dist` branch. Its purpose is to build the ReaPack XML and update `site`
with the new ReaPack.

ReaPack versions are taken from the highest version that exists in `MANIFEST`. There is
one exception: when builds for older API versions are produced and a new release needs to
be cut (e.g. to fix a critical issue in an older API version that doesn't exist in the
latest API version), then the ReaPack version will refer to the highest version from
`MANIFEST` plus a suffix `-<n>` where `<n>` is an incrementing number for each release
that lacks a new build for the latest API version.  When a release occurs that *does*
include a new version of the latest API version, then the ReaPack uses this new version
and the `-<n>` suffix is dropped.  Rinse, repeat.

* ReaPack job
    * Tag is checked out (which applies `dist` branch) in the current directory
    * `master` branch is checked out as `./master/` -- needed for `tools/mkreapack.py`
    * `site` branch is checked out as `./site/`
    * A custom Python script `master/tools/mkreapack.py` is run to generate a new `index.xml` holding the ReaPack
        * The file `site/MANIFEST.reapack` is read. This file contains the `MANIFEST`
          contents the last time the ReaPack was generated.
        * All major version subdirectories (`[0-9]*/`) are crawled and all files excluding `*.md`
          are added as source files to the new ReaPack version segment.
        * For each version in `MANIFEST` that does not exist in `MANIFEST.reapack`, collect `CHANGELOG.md`
          under the applicable API version directory, and consolidate into a ReaPack-wide changelog
        * The new ReaPack version number is generated as described earlier
        * The existing `site/index.xml` file is read
            * All but the most recent 5 `<version>` elements are stripped
            * The new version is inserted at the top
        * The new `site/index.xml` and `site/MANIFEST.reapack` are written back
        * `site` is pushed back, making the new `index.xml` live (via the triggered webhook)
