module TransactionsHelper
  def confidence_badge(v)
    return "" if v.nil?
    val = (v.to_f * 100).round
    level = case v
    when 0.0..0.5 then "Low"
    when 0.5..0.8 then "Medium"
    else "High"
    end
    %Q(<span title="#{val}% confidence" style="font-size:12px;padding:2px 6px;border-radius:10px;border:1px solid #ccc;">AI #{level}</span>).html_safe
  end
end
