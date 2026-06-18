# frozen_string_literal: true

# Public how-to guides: bank statement downloads and Vittio platform usage.
class GuidesController < ApplicationController
  include MarketingLayout

  def index
    @articles = Article.all(section: "guias")
  end

  def show
    @article = Article.find(params[:id], section: "guias")
    raise ActiveRecord::RecordNotFound unless @article

    @related = Article.all(section: "guias").reject { |a| a.slug == @article.slug }.first(3)
  end
end
