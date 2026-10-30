---
paths:
  - "**/*.php"
  - "**/wp-content/**"
  - "**/theme.json"
  - "**/block.json"
  - "**/style.css"
---

# WordPress and PHP

- Never edit WordPress core or third party plugins and themes. Change behavior through hooks (`add_action`, `add_filter`), a child theme or a custom plugin.
- Every PHP file in a plugin or theme starts with `defined( 'ABSPATH' ) || exit;`.
- Prefix everything global (functions, options, hooks, transients, post types) or use a namespace.
- **Sanitize input early** (`sanitize_text_field`, `absint`, `sanitize_email`, `wp_unslash` first) and **escape output late** (`esc_html`, `esc_attr`, `esc_url`, `wp_kses_post`).
- **Every action that changes something** checks a nonce (`check_admin_referer`, `check_ajax_referer`, `wp_verify_nonce`) and a capability (`current_user_can`).
- REST routes always have a real `permission_callback`; never `__return_true` for anything that writes or reads private data.
- Database access through `$wpdb->prepare` for every query with variables, or through WordPress APIs (`WP_Query`, `get_posts`, meta functions).
- Enqueue scripts and styles with `wp_enqueue_script` and `wp_enqueue_style`, with dependencies and a version; no hard coded `<script>` tags.
- Translatable strings with the theme or plugin text domain (`__`, `esc_html__`).
- Block themes: settings and styles in `theme.json`; blocks with `block.json` and the `@wordpress/scripts` build.
- WooCommerce: use the CRUD objects and `wc_get_orders`, not direct post queries, so the code works with HPOS.
- Follow the WordPress Coding Standards (`phpcs` with WPCS) when the repo has them configured.
- Local development with `wp-env` (Docker) or the repo's own setup; never against a live site. Secrets stay in `wp-config.php` outside git or in environment variables.
