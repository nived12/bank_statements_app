# Blog/guías article backed by a Markdown file in content/blog/*.md.
# Not an ActiveRecord model — content lives in version control, not the DB.
# Each file has YAML frontmatter (title, slug, description, date, category,
# section, hero, bank_logo, published) followed by a Markdown body.
class Article
  CONTENT_DIR = Rails.root.join("content", "blog")
  WORDS_PER_MINUTE = 200
  FRONTMATTER = /\A---\s*\n(.*?)\n---\s*\n(.*)\z/m
  SECTIONS = %w[blog guias].freeze

  attr_reader :title, :slug, :description, :category, :section, :hero, :bank_logo, :date, :updated

  class << self
    # Published articles, newest first. Optional section filter ("blog" or "guias").
    def all(section: nil)
      articles = load_all.values.select(&:published?)
      articles = articles.select { |a| a.section == section.to_s } if section.present?
      articles.sort_by(&:date).reverse
    end

    def find(id, section: nil)
      article = load_all[id.to_s]
      return nil unless article
      return article if section.blank?
      return article if article.section == section.to_s

      nil
    end

    # Re-parse on every request in development so new files appear without a
    # restart; memoize everywhere else (small N, static files).
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
        article = parse_file(path)
        memo[article.slug] = article if article&.slug
      end
    end

    def parse_file(path)
      match = File.read(path).match(FRONTMATTER)
      return nil unless match

      front = YAML.safe_load(match[1], permitted_classes: [Date, Time]) || {}
      new(front, match[2])
    end
  end

  def initialize(front, body)
    @title = front["title"]
    @slug = front["slug"]
    @description = front["description"]
    @category = front["category"]
    @section = front.fetch("section", "blog")
    @hero = front["hero"]
    @bank_logo = front["bank_logo"]
    @date = front["date"]&.to_date
    @updated = front["updated"]&.to_date
    @published = front.fetch("published", true)
    @body = body.to_s
  end

  def blog?
    section == "blog"
  end

  def guide?
    section == "guias"
  end

  def published?
    @published && date.present?
  end

  def body_html
    @body_html ||= Commonmarker.to_html(
      @body,
      options: {
        extension: { table: true, strikethrough: true, autolink: true },
        render: { unsafe: false }
      }
    ).html_safe
  end

  def reading_time
    words = @body.split(/\s+/).size
    [(words / WORDS_PER_MINUTE.to_f).ceil, 1].max
  end

  def to_param
    slug
  end
end
