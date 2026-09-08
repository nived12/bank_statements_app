require "rails_helper"

# Guards the real files in content/announcements. A typo in frontmatter does not
# raise anywhere. The campaign just resolves to nothing and the broadcast
# reaches nobody while reporting success.
RSpec.describe "content/announcements", type: :model do
  let(:user) { build(:user, first_name: "Ana") }

  before { Announcement.reset_cache! }

  it "has at least one announcement" do
    expect(Announcement.all).not_to be_empty
  end

  Dir.glob(Rails.root.join("content", "announcements", "*.md")).each do |path|
    basename = File.basename(path, ".md")

    context basename do
      let(:announcement) { Announcement.find(basename) }

      it "parses, and its slug matches the filename" do
        expect(announcement).not_to be_nil
        expect(announcement.slug).to eq(basename)
      end

      it "has a subject" do
        expect(announcement.subject).to be_present
      end

      it "names an audience the broadcast job knows how to resolve" do
        expect(Announcements::BroadcastJob::AUDIENCES).to have_key(announcement.audience)
      end

      it "renders without an unresolved placeholder" do
        expect { announcement.body_html(user) }.not_to raise_error
        expect(announcement.body_html(user)).not_to match(/\{\{/)
      end

      it "pairs a CTA label with a CTA url" do
        expect(announcement.cta_label.present?).to eq(announcement.cta_url.present?)
      end
    end
  end
end
