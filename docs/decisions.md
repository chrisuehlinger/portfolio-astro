# Architecture Decisions

## Static Public Site

WordPress is a build-time content source only. Astro fetches one authenticated aggregate payload during GitHub Actions builds and deploys static files to S3 + CloudFront.

## WordPress Access

WordPress is publicly reachable at `cms.chrisuehlinger.com`, unlinked, `noindex`, and login-required. It is not network-private in v1 so iPad editing and GitHub-triggered flows stay simple.

## Custom Content API

The frontend consumes a plugin-owned endpoint, `/wp-json/portfolio/v1/build`, instead of raw WordPress/ACF APIs. This gives Astro a stable normalized schema.

## No ACF Pro

ACF Free may be used for simple fields, but the site plugin owns custom repeatable media UI, Markdown editing, site settings, and export normalization.

## OpenTofu

Infrastructure is managed with OpenTofu, not Terraform. Remote state uses S3 native locking (`use_lockfile = true`) and no DynamoDB lock table.

## DNS Migration

Route53 becomes authoritative for `chrisuehlinger.com`. Cloudflare is removed from the target architecture. Existing AWS resources are not imported or deleted.

## No Redirects

The new domain does not preserve old URLs. Old content is available through `old.chrisuehlinger.com`, backed by a snapshot of `chrisuehlinger/chrisuehlinger.github.io`.

## Archival CDN

The existing `cdn.chrisuehlinger.com` bucket remains in place for archival media. Its policy is updated non-destructively so CloudFront can replace Cloudflare as the public delivery layer.

## Media

New media uses a private Terraform-managed S3 bucket served only through CloudFront at `media.chrisuehlinger.com`. Uploads are web-ready in v1; no automatic transcoding.

## Deployment Auth

GitHub Actions uses AWS OIDC. WordPress triggers GitHub Actions directly with a fine-grained PAT limited to the repo and Actions write permission. The build API uses a plugin-issued token sent in a build-time POST body so it does not depend on Apache forwarding custom authorization headers.

## Secrets

OpenTofu creates IAM identities and boundaries, but secret values such as WordPress media access keys and CMS build tokens are generated/installed by scripts outside OpenTofu state.
