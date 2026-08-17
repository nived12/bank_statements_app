require "rails_helper"

RSpec.describe "Blog", type: :request do
  let(:content_dir) { Rails.root.join("tmp", "test_blog_content_#{SecureRandom.hex(4)}") }

  def write_article(slug, title: "Título #{slug}", date: "2026-06-01", section: "blog", hero: nil)
    front = {
      "title" => title, "slug" => slug, "description" => "Desc #{slug}",
      "date" => date, "category" => "Guías", "section" => section, "published" => true
    }
    front["hero"] = hero if hero
    yaml = front.map { |k, v| "#{k}: #{v.inspect}" }.join("\n")
    File.write(content_dir.join("#{slug}.md"), "---\n#{yaml}\n---\nCuerpo de #{slug}.")
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

  describe "GET /blog" do
    it "returns success and lists published articles" do
      write_article("primer-articulo", title: "Primer artículo de prueba")

      get "/blog"

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Primer artículo de prueba")
    end
  end

  describe "GET /blog/:id" do
    it "returns success, sets the title, and includes BlogPosting JSON-LD" do
      write_article("articulo-detalle", title: "Artículo de detalle")

      get "/blog/articulo-detalle"

      expect(response).to have_http_status(:success)
      expect(response.body).to include("<title>Artículo de detalle")
      expect(response.body).to include('"@type":"BlogPosting"')
      expect(response.body).to include('"@type":"BreadcrumbList"')
    end

    it "sets og:image to the shared logo card, with its dimensions, when the article has no hero" do
      write_article("articulo-sin-hero")

      get "/blog/articulo-sin-hero"

      expect(response.body).to match(%r{<meta property="og:image" content="[^"]*/og-image\.png">})
      expect(response.body).to include('<meta property="og:image:width" content="1200">')
      expect(response.body).to include('<meta property="og:image:height" content="630">')
    end

    it "sets og:image to the article hero, without dimensions, when present" do
      write_article("articulo-con-hero", title: "Artículo con portada", hero: "/blog/mi-hero.png")

      get "/blog/articulo-con-hero"

      expect(response.body).to include('<meta property="og:image" content="https://vitt.io/blog/mi-hero.png">')
      expect(response.body).to include('<meta property="og:image:alt" content="Artículo con portada">')
      expect(response.body).not_to include('og:image:width')
    end

    it "returns 404 for an unknown slug" do
      get "/blog/no-existe"

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 when article belongs to guides section" do
      write_article("solo-guia", section: "guias")

      get "/blog/solo-guia"

      expect(response).to have_http_status(:not_found)
    end
  end
end
