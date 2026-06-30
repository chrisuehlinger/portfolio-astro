<?php
/**
 * Plugin Name: Portfolio Content
 * Description: Structured CMS and build API for chrisuehlinger.com.
 * Version: 0.1.0
 * Author: Chris Uehlinger
 */

namespace PortfolioContent;

if (!defined('ABSPATH')) {
    exit;
}

const SHOW_POST_TYPE = 'portfolio_show';
const PAGE_POST_TYPE = 'portfolio_page';
const NONCE_ACTION = 'portfolio_content_save';
const NONCE_NAME = 'portfolio_content_nonce';

add_action('init', __NAMESPACE__ . '\\register_post_types');
add_action('add_meta_boxes', __NAMESPACE__ . '\\register_meta_boxes');
add_action('save_post_' . SHOW_POST_TYPE, __NAMESPACE__ . '\\save_show_meta');
add_action('save_post_' . PAGE_POST_TYPE, __NAMESPACE__ . '\\save_page_meta');
add_action('admin_enqueue_scripts', __NAMESPACE__ . '\\enqueue_admin_assets');
add_action('admin_menu', __NAMESPACE__ . '\\register_settings_page');
add_action('rest_api_init', __NAMESPACE__ . '\\register_build_endpoint');
add_action('send_headers', __NAMESPACE__ . '\\send_noindex_header');
add_action('wp_head', __NAMESPACE__ . '\\print_noindex_meta');
add_action('template_redirect', __NAMESPACE__ . '\\require_login_for_cms_frontend');
add_filter('pre_option_blog_public', '__return_zero');
add_filter('rest_authentication_errors', __NAMESPACE__ . '\\restrict_public_rest_api');

function register_post_types(): void
{
    register_post_type(SHOW_POST_TYPE, [
        'labels' => [
            'name' => 'Shows',
            'singular_name' => 'Show',
            'add_new_item' => 'Add Show',
            'edit_item' => 'Edit Show',
        ],
        'public' => false,
        'show_ui' => true,
        'show_in_menu' => true,
        'menu_icon' => 'dashicons-format-video',
        'supports' => ['title', 'page-attributes'],
        'show_in_rest' => false,
        'hierarchical' => false,
    ]);

    register_post_type(PAGE_POST_TYPE, [
        'labels' => [
            'name' => 'Site Pages',
            'singular_name' => 'Site Page',
            'add_new_item' => 'Add Site Page',
            'edit_item' => 'Edit Site Page',
        ],
        'public' => false,
        'show_ui' => true,
        'show_in_menu' => true,
        'menu_icon' => 'dashicons-media-document',
        'supports' => ['title'],
        'show_in_rest' => false,
        'hierarchical' => false,
    ]);
}

function register_meta_boxes(): void
{
    add_meta_box('portfolio_show_details', 'Show Details', __NAMESPACE__ . '\\render_show_details_box', SHOW_POST_TYPE, 'normal', 'high');
    add_meta_box('portfolio_show_featured', 'Featured Display', __NAMESPACE__ . '\\render_show_featured_box', SHOW_POST_TYPE, 'normal', 'default');
    add_meta_box('portfolio_show_media', 'Show Media', __NAMESPACE__ . '\\render_show_media_box', SHOW_POST_TYPE, 'normal', 'default');
    add_meta_box('portfolio_show_markdown', 'Case Study Markdown', __NAMESPACE__ . '\\render_show_markdown_box', SHOW_POST_TYPE, 'normal', 'default');
    add_meta_box('portfolio_page_markdown', 'Markdown', __NAMESPACE__ . '\\render_page_markdown_box', PAGE_POST_TYPE, 'normal', 'high');
    add_meta_box('portfolio_seo', 'SEO', __NAMESPACE__ . '\\render_seo_box', [SHOW_POST_TYPE, PAGE_POST_TYPE], 'side', 'default');
}

function enqueue_admin_assets(string $hook): void
{
    if (!in_array($hook, ['post.php', 'post-new.php', 'toplevel_page_portfolio-settings'], true)) {
        return;
    }

    wp_enqueue_media();
    wp_enqueue_style('portfolio-content-admin', plugins_url('assets/admin.css', __FILE__), [], '0.1.0');
    wp_enqueue_script('portfolio-content-admin', plugins_url('assets/admin.js', __FILE__), ['jquery'], '0.1.0', true);
}

function render_show_details_box(\WP_Post $post): void
{
    wp_nonce_field(NONCE_ACTION, NONCE_NAME);
    $show_date = get_post_meta($post->ID, 'show_date', true);
    $directors = get_post_meta($post->ID, 'directors', true);
    $companies = get_post_meta($post->ID, 'companies', true);
    $role = get_post_meta($post->ID, 'role', true);
    ?>
    <div class="portfolio-fields">
        <label>
            <span>Show date</span>
            <input type="date" name="portfolio_show_date" value="<?php echo esc_attr($show_date); ?>" required>
        </label>
        <label>
            <span>Directors, one per line</span>
            <textarea name="portfolio_directors" rows="4" required><?php echo esc_textarea($directors); ?></textarea>
        </label>
        <label>
            <span>Companies, one per line</span>
            <textarea name="portfolio_companies" rows="4" required><?php echo esc_textarea($companies); ?></textarea>
        </label>
        <label>
            <span>Role</span>
            <input type="text" name="portfolio_role" value="<?php echo esc_attr($role); ?>" required>
        </label>
    </div>
    <?php
}

function render_show_featured_box(\WP_Post $post): void
{
    $featured = (bool) get_post_meta($post->ID, 'featured', true);
    $tile_image_id = (int) get_post_meta($post->ID, 'tile_image_id', true);
    $blurb = get_post_meta($post->ID, 'blurb_markdown', true);
    ?>
    <div class="portfolio-fields">
        <label class="portfolio-checkbox">
            <input type="checkbox" name="portfolio_featured" value="1" <?php checked($featured); ?>>
            <span>Featured on homepage and show detail page</span>
        </label>
        <?php render_attachment_picker('portfolio_tile_image_id', $tile_image_id, 'Tile image'); ?>
        <label>
            <span>One-paragraph blurb Markdown</span>
            <textarea id="portfolio_blurb_markdown" name="portfolio_blurb_markdown" rows="5"><?php echo esc_textarea($blurb); ?></textarea>
        </label>
        <button type="button" class="button portfolio-preview-button" data-source="portfolio_blurb_markdown" data-target="portfolio_blurb_preview">Preview</button>
        <div id="portfolio_blurb_preview" class="portfolio-markdown-preview"></div>
    </div>
    <?php
}

function render_show_media_box(\WP_Post $post): void
{
    $media_json = get_post_meta($post->ID, 'media_items_json', true);
    ?>
    <input type="hidden" id="portfolio_media_json" name="portfolio_media_json" value="<?php echo esc_attr($media_json ?: '[]'); ?>">
    <div id="portfolio-media-list" class="portfolio-media-list"></div>
    <button type="button" class="button" id="portfolio-add-media">Add media item</button>
    <?php
}

function render_show_markdown_box(\WP_Post $post): void
{
    $markdown = get_post_meta($post->ID, 'case_study_markdown', true);
    ?>
    <div class="portfolio-fields">
        <textarea id="portfolio_case_study_markdown" name="portfolio_case_study_markdown" rows="14"><?php echo esc_textarea($markdown); ?></textarea>
        <button type="button" class="button portfolio-preview-button" data-source="portfolio_case_study_markdown" data-target="portfolio_case_study_preview">Preview</button>
        <div id="portfolio_case_study_preview" class="portfolio-markdown-preview"></div>
    </div>
    <?php
}

function render_page_markdown_box(\WP_Post $post): void
{
    wp_nonce_field(NONCE_ACTION, NONCE_NAME);
    $markdown = get_post_meta($post->ID, 'markdown', true);
    ?>
    <div class="portfolio-fields">
        <textarea id="portfolio_page_markdown" name="portfolio_page_markdown" rows="18"><?php echo esc_textarea($markdown); ?></textarea>
        <button type="button" class="button portfolio-preview-button" data-source="portfolio_page_markdown" data-target="portfolio_page_preview">Preview</button>
        <div id="portfolio_page_preview" class="portfolio-markdown-preview"></div>
    </div>
    <?php
}

function render_seo_box(\WP_Post $post): void
{
    $seo_title = get_post_meta($post->ID, 'seo_title', true);
    $seo_description = get_post_meta($post->ID, 'seo_description', true);
    $social_image_id = (int) get_post_meta($post->ID, 'social_image_id', true);
    ?>
    <div class="portfolio-fields compact">
        <label>
            <span>SEO title</span>
            <input type="text" name="portfolio_seo_title" value="<?php echo esc_attr($seo_title); ?>">
        </label>
        <label>
            <span>SEO description</span>
            <textarea name="portfolio_seo_description" rows="4"><?php echo esc_textarea($seo_description); ?></textarea>
        </label>
        <?php render_attachment_picker('portfolio_social_image_id', $social_image_id, 'Social image'); ?>
    </div>
    <?php
}

function render_attachment_picker(string $name, int $attachment_id, string $label): void
{
    $preview = $attachment_id ? wp_get_attachment_image($attachment_id, 'thumbnail') : '';
    ?>
    <label class="portfolio-attachment-picker">
        <span><?php echo esc_html($label); ?></span>
        <input type="number" name="<?php echo esc_attr($name); ?>" id="<?php echo esc_attr($name); ?>" value="<?php echo esc_attr($attachment_id ?: ''); ?>">
        <button type="button" class="button portfolio-pick-attachment" data-target="<?php echo esc_attr($name); ?>">Choose</button>
        <span class="portfolio-attachment-preview"><?php echo $preview; ?></span>
    </label>
    <?php
}

function save_show_meta(int $post_id): void
{
    if (!can_save($post_id)) {
        return;
    }

    update_post_meta($post_id, 'show_date', sanitize_text_field($_POST['portfolio_show_date'] ?? ''));
    update_post_meta($post_id, 'directors', sanitize_textarea_field($_POST['portfolio_directors'] ?? ''));
    update_post_meta($post_id, 'companies', sanitize_textarea_field($_POST['portfolio_companies'] ?? ''));
    update_post_meta($post_id, 'role', sanitize_text_field($_POST['portfolio_role'] ?? ''));
    update_post_meta($post_id, 'featured', isset($_POST['portfolio_featured']) ? '1' : '0');
    update_post_meta($post_id, 'tile_image_id', absint($_POST['portfolio_tile_image_id'] ?? 0));
    update_post_meta($post_id, 'blurb_markdown', wp_kses_post($_POST['portfolio_blurb_markdown'] ?? ''));
    update_post_meta($post_id, 'media_items_json', sanitize_media_json(wp_unslash($_POST['portfolio_media_json'] ?? '[]')));
    update_post_meta($post_id, 'case_study_markdown', wp_kses_post($_POST['portfolio_case_study_markdown'] ?? ''));
    save_seo_meta($post_id);

    if (get_post_status($post_id) === 'publish') {
        trigger_rebuild('show_saved');
    }
}

function save_page_meta(int $post_id): void
{
    if (!can_save($post_id)) {
        return;
    }

    update_post_meta($post_id, 'markdown', wp_kses_post($_POST['portfolio_page_markdown'] ?? ''));
    save_seo_meta($post_id);

    if (get_post_status($post_id) === 'publish') {
        trigger_rebuild('page_saved');
    }
}

function save_seo_meta(int $post_id): void
{
    update_post_meta($post_id, 'seo_title', sanitize_text_field($_POST['portfolio_seo_title'] ?? ''));
    update_post_meta($post_id, 'seo_description', sanitize_textarea_field($_POST['portfolio_seo_description'] ?? ''));
    update_post_meta($post_id, 'social_image_id', absint($_POST['portfolio_social_image_id'] ?? 0));
}

function can_save(int $post_id): bool
{
    if (defined('DOING_AUTOSAVE') && DOING_AUTOSAVE) {
        return false;
    }

    if (!isset($_POST[NONCE_NAME]) || !wp_verify_nonce(sanitize_text_field(wp_unslash($_POST[NONCE_NAME])), NONCE_ACTION)) {
        return false;
    }

    return current_user_can('edit_post', $post_id);
}

function sanitize_media_json(string $json): string
{
    $items = json_decode($json, true);
    if (!is_array($items)) {
        return '[]';
    }

    $clean = [];
    foreach ($items as $item) {
        if (!is_array($item)) {
            continue;
        }

        $type = sanitize_key($item['type'] ?? '');
        if (!in_array($type, ['image', 'video', 'embed'], true)) {
            continue;
        }

        $clean[] = [
            'type' => $type,
            'attachmentId' => absint($item['attachmentId'] ?? 0),
            'posterId' => absint($item['posterId'] ?? 0),
            'provider' => sanitize_key($item['provider'] ?? ''),
            'url' => esc_url_raw($item['url'] ?? ''),
            'title' => sanitize_text_field($item['title'] ?? ''),
            'caption' => sanitize_text_field($item['caption'] ?? ''),
        ];
    }

    return wp_json_encode($clean);
}

function register_settings_page(): void
{
    add_menu_page('Portfolio Settings', 'Portfolio', 'manage_options', 'portfolio-settings', __NAMESPACE__ . '\\render_settings_page', 'dashicons-admin-site', 58);
}

function render_settings_page(): void
{
    if (!current_user_can('manage_options')) {
        return;
    }

    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        check_admin_referer('portfolio_settings_save');
        update_option('portfolio_homepage_hero_video_id', absint($_POST['portfolio_homepage_hero_video_id'] ?? 0));
        update_option('portfolio_homepage_hero_poster_id', absint($_POST['portfolio_homepage_hero_poster_id'] ?? 0));
        update_option('portfolio_resume_intro_markdown', wp_kses_post($_POST['portfolio_resume_intro_markdown'] ?? ''));
        update_option('portfolio_resume_outro_markdown', wp_kses_post($_POST['portfolio_resume_outro_markdown'] ?? ''));
        update_option('portfolio_site_seo_title', sanitize_text_field($_POST['portfolio_site_seo_title'] ?? ''));
        update_option('portfolio_site_seo_description', sanitize_textarea_field($_POST['portfolio_site_seo_description'] ?? ''));
        update_option('portfolio_site_social_image_id', absint($_POST['portfolio_site_social_image_id'] ?? 0));
        trigger_rebuild('settings_saved');
        echo '<div class="updated"><p>Settings saved.</p></div>';
    }

    ?>
    <div class="wrap portfolio-settings">
        <h1>Portfolio Settings</h1>
        <form method="post">
            <?php wp_nonce_field('portfolio_settings_save'); ?>
            <h2>Homepage Hero</h2>
            <?php render_attachment_picker('portfolio_homepage_hero_video_id', (int) get_option('portfolio_homepage_hero_video_id'), 'Hero video'); ?>
            <?php render_attachment_picker('portfolio_homepage_hero_poster_id', (int) get_option('portfolio_homepage_hero_poster_id'), 'Hero poster'); ?>

            <h2>Resume</h2>
            <label>
                <span>Intro Markdown</span>
                <textarea id="portfolio_resume_intro_markdown" name="portfolio_resume_intro_markdown" rows="8"><?php echo esc_textarea(get_option('portfolio_resume_intro_markdown', '')); ?></textarea>
            </label>
            <button type="button" class="button portfolio-preview-button" data-source="portfolio_resume_intro_markdown" data-target="portfolio_resume_intro_preview">Preview</button>
            <div id="portfolio_resume_intro_preview" class="portfolio-markdown-preview"></div>
            <label>
                <span>Outro Markdown</span>
                <textarea id="portfolio_resume_outro_markdown" name="portfolio_resume_outro_markdown" rows="8"><?php echo esc_textarea(get_option('portfolio_resume_outro_markdown', '')); ?></textarea>
            </label>
            <button type="button" class="button portfolio-preview-button" data-source="portfolio_resume_outro_markdown" data-target="portfolio_resume_outro_preview">Preview</button>
            <div id="portfolio_resume_outro_preview" class="portfolio-markdown-preview"></div>

            <h2>Site SEO</h2>
            <label>
                <span>SEO title</span>
                <input type="text" name="portfolio_site_seo_title" value="<?php echo esc_attr(get_option('portfolio_site_seo_title', '')); ?>">
            </label>
            <label>
                <span>SEO description</span>
                <textarea name="portfolio_site_seo_description" rows="4"><?php echo esc_textarea(get_option('portfolio_site_seo_description', '')); ?></textarea>
            </label>
            <?php render_attachment_picker('portfolio_site_social_image_id', (int) get_option('portfolio_site_social_image_id'), 'Social image'); ?>

            <?php submit_button(); ?>
        </form>
    </div>
    <?php
}

function register_build_endpoint(): void
{
    register_rest_route('portfolio/v1', '/build', [
        'methods' => 'GET,POST',
        'callback' => __NAMESPACE__ . '\\build_payload',
        'permission_callback' => '__return_true',
    ]);
}

function has_build_token(?\WP_REST_Request $request = null): bool
{
    $expected = get_build_token();
    if (!$expected) {
        return false;
    }

    $direct_header = $request ? $request->get_header('x-portfolio-build-token') : '';
    if (!$direct_header) {
        $direct_header = $_SERVER['HTTP_X_PORTFOLIO_BUILD_TOKEN'] ?? '';
    }

    if ($direct_header && hash_equals($expected, trim($direct_header))) {
        return true;
    }

    if ($request) {
        $json = $request->get_json_params();
        $body_token = is_array($json) ? ($json['token'] ?? '') : '';
        if ($body_token && hash_equals($expected, trim((string) $body_token))) {
            return true;
        }

        $body_json = json_decode($request->get_body(), true);
        $body_token = is_array($body_json) ? ($body_json['token'] ?? '') : '';
        if ($body_token && hash_equals($expected, trim((string) $body_token))) {
            return true;
        }
    }

    $basic_password = $_SERVER['PHP_AUTH_PW'] ?? '';
    if ($basic_password && hash_equals($expected, $basic_password)) {
        return true;
    }

    $header = $request ? $request->get_header('authorization') : '';
    if (!$header) {
        $header = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
    }

    if (!preg_match('/Bearer\s+(.+)/i', $header, $matches)) {
        return false;
    }

    return hash_equals($expected, trim($matches[1]));
}

function get_build_token(): string
{
    if (defined('PORTFOLIO_BUILD_TOKEN')) {
        return (string) PORTFOLIO_BUILD_TOKEN;
    }

    return (string) getenv('PORTFOLIO_BUILD_TOKEN');
}

function trigger_rebuild(string $reason): void
{
    $token = get_github_token();
    if (!$token || get_transient('portfolio_rebuild_recent')) {
        return;
    }

    set_transient('portfolio_rebuild_recent', '1', 60);

    $repo = defined('PORTFOLIO_GITHUB_REPO') ? PORTFOLIO_GITHUB_REPO : 'chrisuehlinger/portfolio-astro';
    $workflow = defined('PORTFOLIO_GITHUB_WORKFLOW') ? PORTFOLIO_GITHUB_WORKFLOW : 'deploy.yml';
    $ref = defined('PORTFOLIO_GITHUB_REF') ? PORTFOLIO_GITHUB_REF : 'main';

    wp_remote_post("https://api.github.com/repos/{$repo}/actions/workflows/{$workflow}/dispatches", [
        'timeout' => 10,
        'headers' => [
            'Accept' => 'application/vnd.github+json',
            'Authorization' => 'Bearer ' . $token,
            'Content-Type' => 'application/json',
            'User-Agent' => 'portfolio-content-wordpress',
            'X-GitHub-Api-Version' => '2022-11-28',
        ],
        'body' => wp_json_encode([
            'ref' => $ref,
            'inputs' => [
                'reason' => $reason,
            ],
        ]),
    ]);
}

function get_github_token(): string
{
    if (defined('PORTFOLIO_GITHUB_TOKEN')) {
        return (string) PORTFOLIO_GITHUB_TOKEN;
    }

    return (string) getenv('PORTFOLIO_GITHUB_TOKEN');
}

function build_payload(?\WP_REST_Request $request = null)
{
    if (!has_build_token($request)) {
        return new \WP_Error('portfolio_build_forbidden', 'Invalid build token.', ['status' => 401]);
    }

    return [
        'schemaVersion' => 1,
        'generatedAt' => gmdate('c'),
        'site' => build_site_settings(),
        'pages' => build_pages(),
        'shows' => build_shows(),
    ];
}

function build_site_settings(): object
{
    $hero_video_id = (int) get_option('portfolio_homepage_hero_video_id');
    $hero = attachment_video($hero_video_id, (int) get_option('portfolio_homepage_hero_poster_id'));

    return (object) array_filter([
        'seo' => seo_from_values(
            get_option('portfolio_site_seo_title', ''),
            get_option('portfolio_site_seo_description', ''),
            (int) get_option('portfolio_site_social_image_id')
        ),
        'homepageHeroVideo' => $hero,
        'resumeIntroMarkdown' => get_option('portfolio_resume_intro_markdown', ''),
        'resumeOutroMarkdown' => get_option('portfolio_resume_outro_markdown', ''),
    ], __NAMESPACE__ . '\\not_empty_value');
}

function build_pages(): array
{
    $posts = get_posts([
        'post_type' => PAGE_POST_TYPE,
        'post_status' => 'publish',
        'numberposts' => -1,
        'orderby' => 'menu_order title',
        'order' => 'ASC',
    ]);

    return array_map(function (\WP_Post $post): array {
        return array_filter([
            'id' => $post->ID,
            'slug' => $post->post_name,
            'title' => decoded_title($post),
            'markdown' => get_post_meta($post->ID, 'markdown', true),
            'seo' => seo_for_post($post->ID),
        ], __NAMESPACE__ . '\\not_empty_value');
    }, $posts);
}

function build_shows(): array
{
    $posts = get_posts([
        'post_type' => SHOW_POST_TYPE,
        'post_status' => 'publish',
        'numberposts' => -1,
        'orderby' => ['menu_order' => 'ASC', 'meta_value' => 'DESC'],
        'meta_key' => 'show_date',
    ]);

    return array_map(function (\WP_Post $post): array {
        $featured = (bool) get_post_meta($post->ID, 'featured', true);

        return array_filter([
            'id' => $post->ID,
            'slug' => $post->post_name,
            'title' => decoded_title($post),
            'showDate' => get_post_meta($post->ID, 'show_date', true),
            'directors' => lines_to_array(get_post_meta($post->ID, 'directors', true)),
            'companies' => lines_to_array(get_post_meta($post->ID, 'companies', true)),
            'role' => get_post_meta($post->ID, 'role', true),
            'featured' => $featured,
            'menuOrder' => (int) $post->menu_order,
            'blurbMarkdown' => get_post_meta($post->ID, 'blurb_markdown', true),
            'tileImage' => attachment_image((int) get_post_meta($post->ID, 'tile_image_id', true)),
            'media' => normalize_media_items(get_post_meta($post->ID, 'media_items_json', true)),
            'caseStudyMarkdown' => get_post_meta($post->ID, 'case_study_markdown', true),
            'seo' => seo_for_post($post->ID),
        ], __NAMESPACE__ . '\\not_empty_value');
    }, $posts);
}

function normalize_media_items(string $json): array
{
    $items = json_decode($json ?: '[]', true);
    if (!is_array($items)) {
        return [];
    }

    $normalized = [];
    foreach ($items as $item) {
        $type = $item['type'] ?? '';

        if ($type === 'image') {
            $image = attachment_image((int) ($item['attachmentId'] ?? 0));
            if ($image) {
                $image['caption'] = $item['caption'] ?? $image['caption'] ?? null;
                $normalized[] = $image;
            }
        }

        if ($type === 'video') {
            $video = attachment_video((int) ($item['attachmentId'] ?? 0), (int) ($item['posterId'] ?? 0));
            if ($video) {
                $video['caption'] = $item['caption'] ?? null;
                $normalized[] = $video;
            }
        }

        if ($type === 'embed' && !empty($item['url'])) {
            $normalized[] = array_filter([
                'type' => 'embed',
                'provider' => $item['provider'] ?? 'youtube',
                'url' => esc_url_raw($item['url']),
                'title' => sanitize_text_field($item['title'] ?? ''),
                'caption' => sanitize_text_field($item['caption'] ?? ''),
            ], __NAMESPACE__ . '\\not_empty_value');
        }
    }

    return $normalized;
}

function attachment_image(int $attachment_id): ?array
{
    if (!$attachment_id) {
        return null;
    }

    $url = wp_get_attachment_url($attachment_id);
    if (!$url) {
        return null;
    }

    $metadata = wp_get_attachment_metadata($attachment_id) ?: [];

    return array_filter([
        'type' => 'image',
        'url' => $url,
        'alt' => get_post_meta($attachment_id, '_wp_attachment_image_alt', true) ?: '',
        'caption' => wp_get_attachment_caption($attachment_id),
        'width' => isset($metadata['width']) ? (int) $metadata['width'] : null,
        'height' => isset($metadata['height']) ? (int) $metadata['height'] : null,
        'srcset' => wp_get_attachment_image_srcset($attachment_id, 'full') ?: null,
        'sizes' => wp_get_attachment_image_sizes($attachment_id, 'full') ?: null,
    ], __NAMESPACE__ . '\\not_empty_value');
}

function attachment_video(int $attachment_id, int $poster_id = 0): ?array
{
    if (!$attachment_id) {
        return null;
    }

    $url = wp_get_attachment_url($attachment_id);
    if (!$url) {
        return null;
    }

    $metadata = wp_get_attachment_metadata($attachment_id) ?: [];

    return array_filter([
        'type' => 'video',
        'url' => $url,
        'mimeType' => get_post_mime_type($attachment_id) ?: 'video/mp4',
        'caption' => wp_get_attachment_caption($attachment_id),
        'width' => isset($metadata['width']) ? (int) $metadata['width'] : null,
        'height' => isset($metadata['height']) ? (int) $metadata['height'] : null,
        'poster' => attachment_image($poster_id),
    ], __NAMESPACE__ . '\\not_empty_value');
}

function seo_for_post(int $post_id): ?array
{
    return seo_from_values(
        get_post_meta($post_id, 'seo_title', true),
        get_post_meta($post_id, 'seo_description', true),
        (int) get_post_meta($post_id, 'social_image_id', true)
    );
}

function seo_from_values(string $title, string $description, int $social_image_id): ?array
{
    $seo = array_filter([
        'title' => $title,
        'description' => $description,
        'socialImage' => $social_image_id ? wp_get_attachment_url($social_image_id) : null,
    ], __NAMESPACE__ . '\\not_empty_value');

    return $seo ?: null;
}

function lines_to_array(string $value): array
{
    return array_values(array_filter(array_map('trim', preg_split('/\r\n|\r|\n/', $value))));
}

function decoded_title(\WP_Post $post): string
{
    return html_entity_decode(get_the_title($post), ENT_QUOTES | ENT_HTML5, 'UTF-8');
}

function not_empty_value($value): bool
{
    return $value !== null && $value !== '' && $value !== [];
}

function send_noindex_header(): void
{
    header('X-Robots-Tag: noindex, nofollow', true);
}

function print_noindex_meta(): void
{
    echo "<meta name=\"robots\" content=\"noindex,nofollow\">\n";
}

function require_login_for_cms_frontend(): void
{
    if (is_user_logged_in() || is_admin() || wp_doing_ajax() || wp_doing_cron()) {
        return;
    }

    auth_redirect();
}

function restrict_public_rest_api($result)
{
    if (!empty($result) || is_user_logged_in()) {
        return $result;
    }

    $route = $GLOBALS['wp']->query_vars['rest_route'] ?? '';
    $request_uri = $_SERVER['REQUEST_URI'] ?? '';
    if (str_starts_with($route, '/portfolio/v1/build') || str_contains($request_uri, '/wp-json/portfolio/v1/build')) {
        return $result;
    }

    return new \WP_Error('portfolio_rest_forbidden', 'REST API requires authentication.', ['status' => 401]);
}
