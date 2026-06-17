# frozen_string_literal: true

# Public marketing blog/guías. Articles are Markdown files (see Article).
class BlogController < ApplicationController
  include MarketingLayout

  def index
    @articles = Article.all
  end

  def show
    @article = Article.find(params[:slug])
    raise ActiveRecord::RecordNotFound unless @article

    @related = Article.all.reject { |a| a.slug == @article.slug }.first(3)
  end
end
