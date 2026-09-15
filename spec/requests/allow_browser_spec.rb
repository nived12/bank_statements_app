require "rails_helper"

# ApplicationController's allow_browser versions: :modern blocks old browsers
# with a 406, and Rails' default block renders public/406-unsupported-browser.html
# -- a file `rails new` scaffolds automatically but this app never had, since it
# predates that generator default. Every request from a real outdated browser hit
# an ArgumentError instead of the intended 406.
RSpec.describe "unsupported browsers", type: :request do
  # A version old enough to trip :modern (Safari 17.2+) without being read as a
  # bot, which allow_browser exempts regardless of version.
  OLD_SAFARI = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_6) AppleWebKit/605.1.15 " \
               "(KHTML, like Gecko) Version/15.6 Safari/605.1.15"

  it "serves 406, not a 500 from the missing block file" do
    get "/", headers: { "HTTP_USER_AGENT" => OLD_SAFARI }

    expect(response).to have_http_status(:not_acceptable)
  end

  it "still allows a modern browser through" do
    modern = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
             "(KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"

    get "/", headers: { "HTTP_USER_AGENT" => modern }

    expect(response).not_to have_http_status(:not_acceptable)
  end
end
