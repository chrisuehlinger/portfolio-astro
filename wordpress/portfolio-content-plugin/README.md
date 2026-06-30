# Portfolio Content Plugin

This plugin owns the WordPress-side content model for `portfolio-astro`.

## Features

- Registers `Show` and `Site Page` admin types.
- Exposes one authenticated build endpoint: `/wp-json/portfolio/v1/build`.
- Requires the `PORTFOLIO_BUILD_TOKEN` constant.
- Accepts the build token via POST JSON body, Basic auth password, `X-Portfolio-Build-Token`, or Bearer auth.
- Adds noindex headers/meta tags.
- Redirects unauthenticated CMS frontend traffic to login.
- Provides custom Markdown fields, basic Markdown preview, media list editing, and site settings.
- Provides automatic rebuild pause/resume controls and a manual rebuild button.

## Expected Companion Plugins

- WP Offload Media Lite
- Simple Page Ordering

The plugin does not require ACF Pro.
