# frozen_string_literal: true

module ArticlesHelper
  def article_link_path(article)
    if article.guide?
      guide_path(article)
    else
      blog_article_path(article)
    end
  end
end
