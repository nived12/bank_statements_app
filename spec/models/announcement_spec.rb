require "rails_helper"

RSpec.describe Announcement, type: :model do
  let(:content_dir) { Rails.root.join("tmp", "test_announcements_#{SecureRandom.hex(4)}") }

  def write_announcement(slug, front_overrides = {}, body = "Hola {{first_name}}, tenemos noticias.")
    front = {
      "slug" => slug,
      "subject" => "Asunto de #{slug}",
      "audience" => "all",
      "cta_label" => "Ir a mi cuenta",
      "cta_url" => "/subscription"
    }.merge(front_overrides)

    yaml = front.map { |k, v| "#{k}: #{v.inspect}" }.join("\n")
    File.write(content_dir.join("#{slug}.md"), "---\n#{yaml}\n---\n#{body}")
  end

  before do
    FileUtils.mkdir_p(content_dir)
    stub_const("Announcement::CONTENT_DIR", content_dir)
    Announcement.reset_cache!
  end

  after do
    FileUtils.rm_rf(content_dir)
    Announcement.reset_cache!
  end

  describe ".find" do
    it "parses frontmatter into attributes" do
      write_announcement("prueba-extendida", "subject" => "Buenas noticias")

      announcement = Announcement.find("prueba-extendida")

      expect(announcement.slug).to eq("prueba-extendida")
      expect(announcement.subject).to eq("Buenas noticias")
      expect(announcement.audience).to eq("all")
      expect(announcement.cta_label).to eq("Ir a mi cuenta")
      expect(announcement.cta_url).to eq("/subscription")
    end

    it "returns nil for a slug with no file" do
      expect(Announcement.find("no-existe")).to be_nil
    end

    it "ignores a file with no frontmatter" do
      File.write(content_dir.join("suelto.md"), "Sin frontmatter.")

      expect(Announcement.find("suelto")).to be_nil
    end
  end

  describe "#body_html" do
    it "renders markdown and substitutes the user's name" do
      write_announcement("saludo", {}, "Hola **{{first_name}}**, ya casi.")

      html = Announcement.find("saludo").body_html(build(:user, first_name: "Ana"))

      expect(html).to include("<strong>Ana</strong>")
    end

    it "strips raw HTML so copy cannot smuggle markup into the email" do
      write_announcement("crudo", {}, "Hola {{first_name}}<script>alert(1)</script>")

      html = Announcement.find("crudo").body_html(build(:user, first_name: "Ana"))

      expect(html).not_to include("<script>")
    end

    # Percent signs are common in this copy ("50% de descuento"), which is why
    # placeholders are {{braces}} and not format strings.
    it "leaves percent signs alone" do
      write_announcement("porcentaje", {}, "Ahorra 50% este mes, {{first_name}}.")

      html = Announcement.find("porcentaje").body_html(build(:user, first_name: "Ana"))

      expect(html).to include("50%")
    end

    it "raises on an unknown placeholder rather than sending a blank" do
      write_announcement("typo", {}, "Hola {{nombre}}.")

      expect { Announcement.find("typo").body_html(build(:user)) }
        .to raise_error(KeyError, /nombre/)
    end
  end

  describe "#body_text" do
    it "returns the raw markdown with placeholders filled" do
      write_announcement("texto", {}, "Hola **{{first_name}}**.")

      text = Announcement.find("texto").body_text(build(:user, first_name: "Ana"))

      expect(text).to eq("Hola **Ana**.")
    end
  end
end
