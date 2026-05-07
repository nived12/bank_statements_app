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
    # Scripts: same-origin bundles + nonce for inline scripts + unpkg for Swagger docs
    policy.script_src  :self, :strict_dynamic, "https://unpkg.com"
    # Styles: same-origin + inline (Tailwind utilities, Stimulus) + Google Fonts CSS
    policy.style_src   :self, :unsafe_inline, "https://fonts.googleapis.com"
    # Fetch: same-origin API calls and ActiveStorage
    policy.connect_src :self
    # ServiceWorker registration
    policy.worker_src  :self, :blob
    # No framing
    policy.frame_ancestors :none
    # Restrict base tag
    policy.base_uri    :self
  end

  # Per-request nonce injected into script-src and javascript_include_tag
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w(script-src)
end
