# Chris Uehlinger Portfolio

Astro frontend, WordPress CMS companion plugin, and OpenTofu-managed AWS infrastructure for `chrisuehlinger.com`.

The MIT license applies to source code in this repository. Site copy, portfolio content, and externally hosted media are not included in that license.

## Architecture

- Astro + TypeScript generates a static portfolio site.
- WordPress on Lightsail is a CMS/source system only. Public visitors do not hit WordPress.
- A repo-owned WordPress plugin exposes one authenticated aggregate build endpoint: `/wp-json/portfolio/v1/build`.
- GitHub Actions builds on `main` pushes and WordPress-triggered workflow dispatches.
- Static output deploys to S3 and CloudFront. Media is uploaded through WordPress to S3 and served through `media.chrisuehlinger.com`.
- DNS is managed in Route53. Cloudflare is not part of the target architecture.

## Required Tools

- OpenTofu `1.12.3` or newer in the `1.12` line
- AWS CLI v2
- GitHub CLI authenticated as `chrisuehlinger`
- Node.js 22 and npm

On Pop!_OS/Ubuntu, OpenTofu was installed from the official apt repository. Future commands assume `tofu` is available.

## Infrastructure Stacks

OpenTofu root modules live under `infra/stacks/`:

- `bootstrap`: creates the remote state bucket `chrisuehlinger-portfolio-terraform`.
- `dns`: creates the Route53 hosted zone for `chrisuehlinger.com` and outputs nameservers.
- `main`: creates S3 buckets, CloudFront distributions, ACM validation records, Lightsail WordPress, Route53 records, GitHub OIDC IAM, and media upload IAM.

State uses the S3 backend with native lockfiles (`use_lockfile = true`). There is no DynamoDB lock table.

## Bootstrap Order

Run from the repository root.

```bash
infra/scripts/bootstrap-tf-state.sh
infra/scripts/apply-dns.sh
```

After `apply-dns.sh`, update Namecheap nameservers to the Route53 nameservers printed by the DNS stack.

Then run the pre-delegation main apply:

```bash
infra/scripts/apply-main.sh
```

This creates CloudFront distributions without custom aliases/certificates where needed. It also creates ACM DNS validation records in Route53.

After Namecheap delegation has propagated:

```bash
infra/scripts/check-delegation.sh
infra/scripts/apply-main-final.sh
```

The final apply enables custom domains and Route53 aliases for `chrisuehlinger.com`, `www`, `media`, `cdn`, and `old`.

The `main` stack also creates a first-time placeholder `index.html` from `infra/assets/placeholder/`. That object ignores later content changes so OpenTofu does not overwrite Astro deployments.

## DNS Targets

- `chrisuehlinger.com`: Astro static site, CloudFront + private S3.
- `www.chrisuehlinger.com`: redirect distribution/bucket to apex.
- `media.chrisuehlinger.com`: new WordPress-uploaded media, CloudFront + private S3.
- `cdn.chrisuehlinger.com`: archival old media, CloudFront in front of the existing `cdn.chrisuehlinger.com` S3 website bucket.
- `old.chrisuehlinger.com`: snapshot of `chrisuehlinger/chrisuehlinger.github.io`, CloudFront + private S3.
- `cms.chrisuehlinger.com`: direct Route53 A record to Lightsail static IP. HTTPS is configured on the instance with Let's Encrypt.

## Scripts

- `infra/scripts/bootstrap-tf-state.sh`: creates remote state bucket using the bootstrap stack.
- `infra/scripts/apply-dns.sh`: creates/updates the Route53 hosted zone and prints nameservers.
- `infra/scripts/check-delegation.sh`: checks whether public NS delegation points to Route53.
- `infra/scripts/apply-main.sh`: applies main infrastructure with `enable_custom_domains=false`.
- `infra/scripts/apply-main-final.sh`: checks delegation, then applies main infrastructure with `enable_custom_domains=true`.
- `infra/scripts/snapshot-old-site.sh`: clones `chrisuehlinger/chrisuehlinger.github.io` and syncs it to the `old` archive bucket.
- `infra/scripts/install-wp-plugin.sh`: installs/updates the custom WordPress plugin and activates WP Offload Media Lite and Simple Page Ordering.
- `infra/scripts/install-wp-secrets.sh`: generates/installs CMS-side secrets and WordPress media IAM keys without storing secret values in OpenTofu state.
- `infra/scripts/configure-cms-https.sh`: opens the Bitnami HTTPS tool over SSH with the correct values documented in the prompt output.
- `infra/scripts/configure-github-secrets.sh`: configures GitHub repository secrets from OpenTofu outputs and the local ignored CMS token.
- `infra/scripts/deploy-site.sh`: syncs `dist/` to the site bucket and invalidates the site CloudFront distribution.

Scripts are intended to be safe to rerun and must not print raw secret values.

## WordPress Setup

After `main` is applied, install the CMS plugin and server-side constants:

```bash
infra/scripts/install-wp-plugin.sh
infra/scripts/install-wp-secrets.sh
infra/scripts/configure-cms-https.sh
```

The build endpoint is authenticated with `PORTFOLIO_BUILD_TOKEN`. Astro sends the token in a POST JSON body to avoid Apache header forwarding edge cases:

```bash
CMS_BUILD_ENDPOINT=https://cms.chrisuehlinger.com/wp-json/portfolio/v1/build
CMS_BUILD_TOKEN=...
```

For WordPress-triggered rebuilds, add a fine-grained GitHub PAT with Actions write access to `.tmp/secrets/github-actions-pat` or pass `PORTFOLIO_GITHUB_TOKEN` when running `install-wp-secrets.sh`.

The Portfolio settings page includes rebuild controls:

- `Automatically rebuild on publish/update`: when enabled, published content saves trigger GitHub Actions with a short debounce.
- `Trigger rebuild now`: forces one workflow dispatch and clears the pending-changes flag.
- When automatic rebuilds are disabled, saves mark content as dirty but do not dispatch GitHub Actions.

## GitHub Actions Setup

Create/configure the repository, then set deploy secrets:

```bash
infra/scripts/configure-github-secrets.sh
```

The script sets:

- `AWS_ROLE_ARN`
- `SITE_BUCKET`
- `SITE_CLOUDFRONT_DISTRIBUTION_ID`
- `CMS_BUILD_ENDPOINT`
- `CMS_BUILD_TOKEN`

GitHub Actions uses OIDC for AWS deploy access and does not need OpenTofu state access.

## Local Build

Build and deploy locally with:

```bash
CMS_BUILD_ENDPOINT=https://cms.chrisuehlinger.com/wp-json/portfolio/v1/build \
CMS_BUILD_TOKEN="$(<.tmp/secrets/cms-build-token)" \
npm run build

npm run deploy
```

## Content Decisions

- Published show records appear on Resume.
- Featured show records appear on the homepage and get public `/shows/{slug}/` pages.
- Show title is the WordPress post title. Public slug is the WordPress post slug.
- Required show fields: `showDate` (`YYYY-MM-DD`), directors list, companies list, and roles list.
- Featured shows require a 4:3 tile image.
- Featured ordering uses WordPress `menu_order` with Simple Page Ordering.
- Show pages render a required blurb, ordered structured media, and optional text-only Markdown case study.
- Media types are image, video, and controlled embeds only.
- About/simple pages are plugin-managed Markdown records.
- Resume is generated from show records plus optional Markdown intro/outro.
- Future posts are reserved for `/blog/`, but blog is not implemented in v1.

See [docs/decisions.md](docs/decisions.md) for the decision log.
