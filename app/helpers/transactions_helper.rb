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

  def render_sort_indicator(column)
    return "" unless @current_sort == column

    if @current_direction == "asc"
      # Up arrow for ascending
      '<svg class="inline w-4 h-4 ml-1 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7"></path>
      </svg>'.html_safe
    else
      # Down arrow for descending
      '<svg class="inline w-4 h-4 ml-1 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
      </svg>'.html_safe
    end
  end
end
