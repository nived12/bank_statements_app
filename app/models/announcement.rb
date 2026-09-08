# Broadcast email backed by a Markdown file in content/announcements/*.md.
# Not an ActiveRecord model. Copy lives in version control alongside the
# feature it announces, the same trade-off Article makes for the blog.
#
# Frontmatter carries subject, audience and CTA; the body is Markdown. The CTA
# cannot live in the body because Commonmarker strips raw HTML, so the button is
# rendered by the view from cta_label/cta_url.
class Announcement
  CONTENT_DIR = Rails.root.join("content", "announcements")
  FRONTMATTER = /\A---\s*\n(.*?)\n---\s*\n(.*)\z/m
  PLACEHOLDER = /\{\{(\w+)\}\}/

  attr_reader :slug, :subject, :audience, :cta_label, :cta_url

  class << self
    def all
      load_all.values
    end

    def find(slug)
      load_all[slug.to_s]
    end

    def load_all
      return parse_all if Rails.env.development?

      @load_all ||= parse_all
    end

    def reset_cache!
      @load_all = nil
    end

    private

    def parse_all
      return {} unless Dir.exist?(CONTENT_DIR)

      Dir.glob(CONTENT_DIR.join("*.md")).each_with_object({}) do |path, memo|
        announcement = parse_file(path)
        memo[announcement.slug] = announcement if announcement&.slug
      end
    end

    def parse_file(path)
      match = File.read(path).match(FRONTMATTER)
      return nil unless match

      new(YAML.safe_load(match[1], permitted_classes: [ Date, Time ]) || {}, match[2])
    end
  end

  def initialize(front, body)
    @slug = front["slug"]
    @subject = front["subject"]
    @audience = front["audience"]
    @cta_label = front["cta_label"]
    @cta_url = front["cta_url"]
    @body = body
  end

  def body_html(user)
    Commonmarker.to_html(
      body_text(user),
      options: {
        extension: { table: true, strikethrough: true, autolink: true },
        render: { unsafe: false }
      }
    ).html_safe
  end

  # Markdown is readable as-is, so this doubles as the text/plain part.
  def body_text(user)
    variables = { "first_name" => user.first_name }

    @body.gsub(PLACEHOLDER) do
      key = Regexp.last_match(1)
      # Loud on a typo: a silent blank would ship "Hola ," to everyone, and the
      # preview is where that should surface.
      variables.fetch(key) { raise KeyError, "unknown placeholder {{#{key}}} in announcement #{slug}" }
    end
  end
end
