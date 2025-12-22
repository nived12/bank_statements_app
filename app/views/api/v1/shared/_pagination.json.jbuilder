# frozen_string_literal: true

# Shared pagination metadata partial for API responses
# Usage: json.partial!("api/v1/shared/pagination", pagy: @pagy)
#
# Returns pagination info following modern API best practices:
# - current_page: Current page number
# - next_page: Next page number (null if on last page)
# - prev_page: Previous page number (null if on first page)
# - total_pages: Total number of pages available
# - total_items: Total number of items across all pages
# - page_size: Number of items per page
# - from: Record number of first item on this page (e.g., 21)
# - to: Record number of last item on this page (e.g., 40)
#
# The client can use next_page/prev_page to easily navigate:
# GET /api/v1/transactions?page=#{next_page}

json.current_page(pagy.page)
json.next_page(pagy.next)
json.prev_page(pagy.prev)
json.total_pages(pagy.pages)
json.total_items(pagy.count)
json.page_size(pagy.limit)
json.from(pagy.from)
json.to(pagy.to)
