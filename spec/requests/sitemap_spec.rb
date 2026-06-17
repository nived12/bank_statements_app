require "rails_helper"

RSpec.describe "Sitemap", type: :request do
  let(:content_dir) { Rails.root.join("tmp", "test_blog_content_#{SecureRandom.hex(4)}") }

  before do
    FileUtils.mkdir_p(content_dir)
    stub_const("Article::CONTENT_DIR", content_dir)
    Article.reset_cache!

    front = {
      "title" => "Artículo sitemap", "slug" => "articulo-sitemap", "description" => "Desc",
      "date" => "2026-06-01", "category" => "Guías", "published" => true
    }
    yaml = front.map { |k, v| "#{k}: #{v.inspect}" }.join("\n")
    File.write(content_dir.join("articulo-sitemap.md"), "---\n#{yaml}\n---\nCuerpo.")
  end

  after do
    FileUtils.rm_rf(content_dir)
    Article.reset_cache!
  end

  describe "GET /sitemap.xml" do
    it "returns XML including the blog index and each published article" do
      get "/sitemap.xml"

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq("application/xml")
      expect(response.body).to include("<loc>https://vitt.io/blog</loc>")
      expect(response.body).to include("<loc>https://vitt.io/blog/articulo-sitemap</loc>")
    end
  end
end
