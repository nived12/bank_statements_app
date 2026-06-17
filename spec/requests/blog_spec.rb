require "rails_helper"

RSpec.describe "Blog", type: :request do
  let(:content_dir) { Rails.root.join("tmp", "test_blog_content_#{SecureRandom.hex(4)}") }

  def write_article(slug, title: "Título #{slug}", date: "2026-06-01")
    front = {
      "title" => title, "slug" => slug, "description" => "Desc #{slug}",
      "date" => date, "category" => "Guías", "published" => true
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

  describe "GET /blog" do
    it "returns success and lists published articles" do
      write_article("primer-articulo", title: "Primer artículo de prueba")

      get "/blog"

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Primer artículo de prueba")
    end
  end

  describe "GET /blog/:slug" do
    it "returns success, sets the title, and includes BlogPosting JSON-LD" do
      write_article("articulo-detalle", title: "Artículo de detalle")

      get "/blog/articulo-detalle"

      expect(response).to have_http_status(:success)
      expect(response.body).to include("<title>Artículo de detalle")
      expect(response.body).to include('"@type":"BlogPosting"')
      expect(response.body).to include('"@type":"BreadcrumbList"')
    end

    it "returns 404 for an unknown slug" do
      get "/blog/no-existe"

      expect(response).to have_http_status(:not_found)
    end
  end
end
