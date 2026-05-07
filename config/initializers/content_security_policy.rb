# Be sure to restart your server when you modify this file.

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    # Fonts: Inter from Google Fonts
    policy.font_src    :self, :data, "https://fonts.gstatic.com"
    # Images: ActiveStorage blobs, data URIs, external avatars
    policy.img_src     :self, :data, :blob, "https:"
    # No plugins
    policy.object_src  :none
    # Scripts: same-origin bundles, inline scripts (app uses many view-level inline scripts),
    # and unpkg for Swagger docs. unsafe_inline is required while the app uses inline
    # global functions (onclick handlers, view scripts). Nonces are already added to all
    # <script> blocks as a forward-looking step toward removing unsafe_inline.
    policy.script_src  :self, :unsafe_inline, "https://unpkg.com"
    # Styles: same-origin + inline (Tailwind utilities, Stimulus) + Google Fonts CSS
    policy.style_src   :self, :unsafe_inline, "https://fonts.googleapis.com"
    # Fetch: same-origin API calls and ActiveStorage
    policy.connect_src :self
    # ServiceWorker registration
    policy.worker_src  :self, :blob
    # No framing
    policy.frame_ancestors :none
    # Restrict base tag
    policy.base_uri :self
  end

  # Nonce generator kept for forward-compatibility — nonces are already added to all
  # view-level <script> blocks. The directive list is intentionally EMPTY while unsafe_inline
  # is active: adding a nonce to the script-src header causes Chrome to ignore unsafe-inline
  # (CSP Level 3 spec), which silently blocks inline event handlers (onclick, onchange).
  # When unsafe_inline is eventually removed, add "script-src" back to nonce_directives and
  # migrate inline handlers to Stimulus — the nonce attributes on <script> blocks are already
  # in place so view changes won't be needed.
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[]
end
