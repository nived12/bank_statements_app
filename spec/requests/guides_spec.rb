# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Guides", type: :request do
  let(:content_dir) { Rails.root.join("tmp", "test_blog_content_#{SecureRandom.hex(4)}") }

  def write_article(slug, title: "Título #{slug}", date: "2026-06-01", section: "guias")
    front = {
      "title" => title, "slug" => slug, "description" => "Desc #{slug}",
      "date" => date, "category" => "Guías", "section" => section, "published" => true
    }
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
