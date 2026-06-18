# frozen_string_literal: true

# Dynamic XML sitemap so new blog articles are indexed automatically.
class SitemapController < ApplicationController
  skip_before_action :authenticate!
  skip_before_action :check_legal_consent!

  def index
    @blog_articles = Article.all(section: "blog")
    @guide_articles = Article.all(section: "guias")
    render layout: false, content_type: "application/xml"
  end
end
