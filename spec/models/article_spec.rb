require "rails_helper"

RSpec.describe Article, type: :model do
  let(:content_dir) { Rails.root.join("tmp", "test_blog_content_#{SecureRandom.hex(4)}") }

  def write_article(slug, front_overrides = {}, body = "Cuerpo del artículo.")
    front = {
      "title" => "Título #{slug}",
      "slug" => slug,
      "description" => "Descripción #{slug}",
      "date" => "2026-06-01",
      "category" => "Guías",
      "published" => true
    }.merge(front_overrides)

    yaml = front.map { |k, v| "#{k}: #{v.inspect}" }.join("\n")
    File.write(content_dir.join("#{slug}.md"), "---\n#{yaml}\n---\n#{body}")
  end

  before do
    FileUtils.mkdir_p(content_dir)
    stub_const("Article::CONTENT_DIR", content_dir)
    Article.reset_cache!
  end

  after do
    FileUtils.rm_rf(content_dir)
    Article.reset_cache!
  end

  describe ".all" do
    it "returns only published articles" do
      write_article("publicado", "published" => true)
      write_article("borrador", "published" => false)

      expect(Article.all.map(&:slug)).to eq(["publicado"])
    end

    it "orders by date, newest first" do
      write_article("viejo", "date" => "2026-01-01")
      write_article("nuevo", "date" => "2026-06-01")

      expect(Article.all.map(&:slug)).to eq(%w[nuevo viejo])
    end
  end

  describe ".find" do
    it "returns the article matching the slug" do
      write_article("mi-articulo")

      expect(Article.find("mi-articulo").title).to eq("Título mi-articulo")
    end

    it "returns nil when the slug does not exist" do
      expect(Article.find("no-existe")).to be_nil
    end
  end

  describe "#body_html" do
    it "renders Markdown to HTML" do
      write_article("con-formato", {}, "Texto con **negritas** y una [liga](/pricing).")

      html = Article.find("con-formato").body_html

      expect(html).to include("<strong>negritas</strong>")
      expect(html).to include('<a href="/pricing">liga</a>')
    end
  end

  describe "#reading_time" do
    it "estimates minutes based on word count" do
      write_article("corto", {}, (["palabra"] * 50).join(" "))

      expect(Article.find("corto").reading_time).to eq(1)
    end

    it "never returns less than 1 minute" do
      write_article("vacio", {}, "")

      expect(Article.find("vacio").reading_time).to eq(1)
    end
  end

  describe "#published?" do
    it "is false without a date even if published is true" do
      write_article("sin-fecha", "published" => true)
      path = content_dir.join("sin-fecha.md")
      File.write(path, File.read(path).sub(/^date:.*\n/, ""))

      expect(Article.find("sin-fecha").published?).to be(false)
    end
  end
end
