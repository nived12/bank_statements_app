require "rails_helper"

RSpec.describe PdfParser::Concerns::TrackingKey do
  # The concern exposes a private helper; exercise it through a bare includer the
  # same way the real parsers use it.
  let(:extractor) do
    Class.new do
      include PdfParser::Concerns::TrackingKey

      public :extract_tracking_key
    end.new
  end

  # Every sample below is copied verbatim from a real statement so the regexes are
  # pinned to what the banks actually print, not to an idealised format.
  describe "#extract_tracking_key" do
    context "labeled forms" do
      it "reads Santander's CLAVE DE RASTREO" do
        text = <<~TXT
          ABONO PORTABILIDAD DE NOMINA HORA 02:02:13
          RECIBIDO DE BBVA MEXICO
          CLAVE DE RASTREO 2026070240012NNNN0000114058
          REF 3399481
        TXT

        expect(extractor.extract_tracking_key(text)).to eq("2026070240012NNNN0000114058")
      end

      it "reads Banorte's CVE RAST even when the value wraps to the next line" do
        text = <<~TXT
          03-JUL-26 SPEI RECIBIDO, BCO:0014 SANTANDER HR LIQ: 12:22:03
          HAVN961009GZ6 CONCEPTO: TRANSFERENCIA A NIVED BANORTE REFERENCIA: 2774966 CVE RAST:
          2026070340014BMOVP000403807730
        TXT

        expect(extractor.extract_tracking_key(text)).to eq("2026070340014BMOVP000403807730")
      end

      it "reads the whitespace-stripped CVERASTREO: variant" do
        text = "SPEIRECIBIDO CVERASTREO:MBAN01002606290077383061"

        expect(extractor.extract_tracking_key(text)).to eq("MBAN01002606290077383061")
      end

      it "reads Nu's lowercase 'Clave de rastreo'" do
        text = "Transferencia recibida, Clave de rastreo 2026071840014BMOVP000406328190, de Nived"

        expect(extractor.extract_tracking_key(text)).to eq("2026071840014BMOVP000406328190")
      end
    end

    context "unlabeled forms" do
      it "reads BBVA's bare date-prefixed clave on its own line" do
        text = <<~TXT
          18/JUL   20/JUL SPEI RECIBIDOSANTANDER                       14,000.00
                   0192778381 014 9788921TRANSFERENCIA A NIVED BANCOMER
                   00014580140409590176
                   2026071840014BMOVP000406328190
        TXT

        expect(extractor.extract_tracking_key(text)).to eq("2026071840014BMOVP000406328190")
      end

      it "reads BBVA's MBAN-prefixed clave" do
        text = <<~TXT
          07/JUL   07/JUL SPEI ENVIADO SANTANDER                          800.00
                   0086647893 014 2206260servicio parabrisas
                   MBAN01002607070086647893
        TXT

        expect(extractor.extract_tracking_key(text)).to eq("MBAN01002607070086647893")
      end

      it "reads STP's REVO-prefixed clave" do
        text = "SPEI RECIBIDO, BCO:0646 STP CVE RAST: REVO20260703IVSINBF4LTSNLLD85P"

        expect(extractor.extract_tracking_key(text)).to eq("REVO20260703IVSINBF4LTSNLLD85P")
      end

      # Statement text runs the clave straight into the next word with no space, and an
      # open-ended tail swallowed it — production backfilled the 42-character
      # "REVO20260703IVSINBF4LTSNLLD85PSPEIRECIBIDO", which can never match the clean
      # copy the other bank prints. A clave is at most 30 characters, so the tail is
      # fixed-width rather than greedy.
      it "stops at the end of the clave when the next word is glued to it" do
        text = "REVO20260703IVSINBF4LTSNLLD85PSPEIRECIBIDO"

        expect(extractor.extract_tracking_key(text)).to eq("REVO20260703IVSINBF4LTSNLLD85P")
      end
    end

    context "when there is no key" do
      it "returns nil for an ordinary card purchase" do
        expect(extractor.extract_tracking_key("ZARA CUMBRES ZMC 960801538")).to be_nil
      end

      it "returns nil for blank input" do
        expect(extractor.extract_tracking_key(nil)).to be_nil
        expect(extractor.extract_tracking_key("")).to be_nil
      end

      it "does not mistake an 18-digit CLABE for a tracking key" do
        # The CLABE sits directly above the real clave in BBVA statements; picking it
        # up would pair transactions by account number instead of by operation.
        expect(extractor.extract_tracking_key("00014580140409590176")).to be_nil
      end
    end

    it "prefers the labeled value when both a label and stray digits are present" do
      text = <<~TXT
        REFERENCIA: 2774966
        00014580140409590176
        CLAVE DE RASTREO 2026073040012NNNN0000283309
      TXT

      expect(extractor.extract_tracking_key(text)).to eq("2026073040012NNNN0000283309")
    end

    it "strips a trailing comma or period left by the surrounding prose" do
      text = "Clave de rastreo 2026072540014BMOVP000401175190."

      expect(extractor.extract_tracking_key(text)).to eq("2026072540014BMOVP000401175190")
    end
  end

  describe "#tracking_keys_by_amount" do
    it "pairs each amount with the clave printed beneath it" do
      # Verbatim BBVA layout: amount on the header row, clave three lines down.
      text = <<~TXT
        18/JUL   20/JUL SPEI RECIBIDOSANTANDER                       14,000.00
                 0192778381 014 9788921TRANSFERENCIA A NIVED BANCOMER
                 00014580140409590176
                 2026071840014BMOVP000406328190
        25/JUL   27/JUL SPEI RECIBIDOSANTANDER                        1,000.00
                 0129126270 014 7073869TRANSFERENCIA A NIVED BANCOMER
                 00014580140409590176
                 2026072540014BMOVP000401175190
      TXT

      expect(extractor.tracking_keys_by_amount(text)).to include(
        BigDecimal("14000.00") => "2026071840014BMOVP000406328190",
        BigDecimal("1000.00") => "2026072540014BMOVP000401175190"
      )
    end

    it "handles the labeled Santander layout" do
      text = <<~TXT
        20-JUL-2026 0632819 PAGO TRANSFERENCIA SPEI HORA 21:48:51     14,000.00     22,953.94
                    ENVIADO A BBVA MEXICO
                    CLAVE DE RASTREO 2026071840014BMOVP000406328190
      TXT

      expect(extractor.tracking_keys_by_amount(text)[BigDecimal("14000.00")])
        .to eq("2026071840014BMOVP000406328190")
    end

    it "drops an amount that could belong to more than one clave" do
      # Two transfers of the same amount: guessing either would risk pairing the
      # wrong two rows, so neither is offered.
      text = <<~TXT
        01/JUL SPEI ENVIADO                                           1,000.00
               2026070140014BMOVP000400000001
        05/JUL SPEI ENVIADO                                           1,000.00
               2026070540014BMOVP000400000002
      TXT

      expect(extractor.tracking_keys_by_amount(text)).not_to have_key(BigDecimal("1000.00"))
    end

    it "returns an empty hash for text with no keys" do
      expect(extractor.tracking_keys_by_amount("ZARA CUMBRES 2,210.00")).to eq({})
      expect(extractor.tracking_keys_by_amount(nil)).to eq({})
    end
  end
end
