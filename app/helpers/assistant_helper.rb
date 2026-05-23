# frozen_string_literal: true

module AssistantHelper
  # Groups conversations into Claude-style time buckets for the history rail.
  # Returns one of: :today, :yesterday, :this_week, :earlier.
  def recency_bucket(time)
    return :earlier if time.nil?

    today = Time.current.to_date
    date  = time.in_time_zone(Time.zone).to_date

    return :today      if date == today
    return :yesterday  if date == today - 1
    return :this_week  if date >= today - 6

    :earlier
  end

  # Tiny markdown → HTML for assistant message bubbles.
  # Handles **bold**, *italic*, bullet lists ("- " or "* "), and paragraph breaks.
  # Escapes HTML first so user/LLM content can't inject markup.
  def render_assistant_markdown(text)
    return "".html_safe if text.blank?

    escaped = ERB::Util.html_escape(text.to_s)
    lines = escaped.split("\n")

    html = +""
    in_list = false
    paragraph = []

    flush_paragraph = lambda do
      next if paragraph.empty?

      html << "<p>#{paragraph.join("<br>")}</p>"
      paragraph.clear
    end

    lines.each do |line|
      stripped = line.strip
      if stripped.match?(/\A[-*]\s+/)
        flush_paragraph.call
        unless in_list
          html << "<ul>"
          in_list = true
        end
        item = stripped.sub(/\A[-*]\s+/, "")
        html << "<li>#{inline_md(item)}</li>"
      elsif stripped.empty?
        flush_paragraph.call
        if in_list
          html << "</ul>"
          in_list = false
        end
      else
        if in_list
          html << "</ul>"
          in_list = false
        end
        paragraph << inline_md(stripped)
      end
    end

    flush_paragraph.call
    html << "</ul>" if in_list

    html.html_safe
  end

  private

  def inline_md(text)
    text
      .gsub(/\*\*(.+?)\*\*/, '<strong>\1</strong>')
      .gsub(/(?<![\*\w])\*(?!\s)(.+?)(?<!\s)\*(?!\w)/, '<em>\1</em>')
  end
end
