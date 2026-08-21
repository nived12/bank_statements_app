require "rails_helper"

# The block this guards is a workaround, and the kind that fails silently: it re-declares
# `.hidden` after Tailwind's utilities so it beats `.inline-flex` and friends, which means
# every responsive display utility has to be re-declared after it too. For a long time the
# block listed only md:block/flex/grid/hidden, and the app's one `hidden md:inline-flex`
# button rendered as display:none on every desktop — invisible, with nothing failing.
RSpec.describe "Responsive display utilities in application.tailwind.css" do
  BREAKPOINTS = { "sm" => "640px", "md" => "768px", "lg" => "1024px", "xl" => "1280px" }.freeze
  DISPLAYS = %w[block flex grid contents inline inline-block inline-flex table hidden].freeze

  let(:css) { Rails.root.join("app/assets/stylesheets/application.tailwind.css").read }

  # Only what follows the bare `.hidden` can override it, so that is the only region
  # worth asserting on — the file has unrelated media blocks above it.
  let(:after_hidden) do
    offset = css.index(/^\.hidden\s*\{\s*display:\s*none;\s*\}/)
    raise "no bare .hidden declaration found" if offset.nil?

    css[offset..]
  end

  it "declares a bare .hidden that overrides Tailwind's own utilities" do
    expect(css).to match(/^\.hidden\s*\{\s*display:\s*none;\s*\}/)
  end

  BREAKPOINTS.each do |breakpoint, width|
    context "at #{breakpoint} (#{width})" do
      it "has a media block after the bare .hidden" do
        expect(after_hidden).to include("@media (min-width: #{width})")
      end

      DISPLAYS.each do |display|
        it "re-declares #{breakpoint}:#{display} after it" do
          expect(after_hidden).to include(".#{breakpoint}\\:#{display}")
        end
      end
    end
  end

  it "covers every breakpoint the views actually use with a responsive display class" do
    used = Dir[Rails.root.join("app/views/**/*.erb")]
      .flat_map { |path| File.read(path).scan(/\b(sm|md|lg|xl|2xl):(?:#{DISPLAYS.join("|")})\b/) }
      .flatten.uniq

    expect(used - BREAKPOINTS.keys).to be_empty
  end
end
