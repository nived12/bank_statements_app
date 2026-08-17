# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Guides", type: :request do
  let(:content_dir) { Rails.root.join("tmp", "test_blog_content_#{SecureRandom.hex(4)}") }

  def write_article(slug, title: "Título #{slug}", date: "2026-06-01", section: "guias", hero: nil)
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

  describe "GET /guides" do
    it "returns success and lists published guide articles" do
      write_article("primera-guia", title: "Primera guía de prueba")

      get "/guides"

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Primera guía de prueba")
    end
  end

  describe "GET /guides/:id" do
    it "returns success, sets the title, and includes BlogPosting JSON-LD" do
      write_article("guia-detalle", title: "Guía de detalle")

      get "/guides/guia-detalle"

      expect(response).to have_http_status(:success)
      expect(response.body).to include("<title>Guía de detalle")
      expect(response.body).to include('"@type":"BlogPosting"')
      expect(response.body).to include('"@type":"BreadcrumbList"')
    end

    it "sets og:image to the shared logo card, with its dimensions, when the article has no hero" do
      write_article("guia-sin-hero")

      get "/guides/guia-sin-hero"

      expect(response.body).to match(%r{<meta property="og:image" content="[^"]*/og-image\.png">})
      expect(response.body).to include('<meta property="og:image:width" content="1200">')
      expect(response.body).to include('<meta property="og:image:height" content="630">')
    end

    it "sets og:image to the article hero, without dimensions, when present" do
      write_article("guia-con-hero", title: "Guía con portada", hero: "/blog/mi-hero.png")

      get "/guides/guia-con-hero"

      expect(response.body).to include('<meta property="og:image" content="https://vitt.io/blog/mi-hero.png">')
      expect(response.body).to include('<meta property="og:image:alt" content="Guía con portada">')
      expect(response.body).not_to include('og:image:width')
    end

    it "returns 404 for an unknown slug" do
      get "/guides/no-existe"

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 when article belongs to blog section" do
      write_article("solo-blog", section: "blog")

      get "/guides/solo-blog"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "redirects from old blog URLs" do
    it "redirects moved bank guide from /blog to /guides" do
      get "/blog/como-leer-estado-cuenta-bbva"

      expect(response).to redirect_to("/guides/como-leer-estado-cuenta-bbva")
      expect(response).to have_http_status(:moved_permanently)
    end
  end
end
