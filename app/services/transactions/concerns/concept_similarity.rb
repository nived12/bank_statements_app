module Transactions
  module Concerns
    module ConceptSimilarity
      SIMILARITY_THRESHOLD = 0.2

      # Returns true if the incoming statement transaction (JSON Hash) is similar
      # enough to an existing Transaction record to be considered a duplicate.
      # Takes the highest score across description and concept comparisons so that
      # a clean manual entry ("servicio jardineria") matches a noisy statement import
      # ("PAGO CUENTA DE TERCERO BNET 1234567 servicio jardineria") via its concept.
      def concept_similar_enough?(incoming, existing)
        description = incoming["description"].to_s.squish
        concept = incoming["concept"].to_s.squish

        desc_similarity = calculate_similarity(description, existing.description)
        concept_similarity = if concept.present?
          [
            calculate_similarity(concept, existing.description),
            calculate_similarity(concept, existing.concept.to_s)
          ].max
        else
          0.0
        end

        [desc_similarity, concept_similarity].max >= SIMILARITY_THRESHOLD
      end

      private

      def calculate_similarity(text1, text2)
        return 0.0 if text1.blank? || text2.blank?
        return 1.0 if text1 == text2

        words1 = normalize_text(text1).split(/\s+/).to_set
        words2 = normalize_text(text2).split(/\s+/).to_set

        intersection = words1 & words2
        union = words1 | words2

        return 0.0 if union.empty?

        intersection.size.to_f / union.size
      end

      def normalize_text(text)
        text.to_s.downcase
            .gsub(/[^\w\s]/, " ")
            .gsub(/\s+/, " ")
            .strip
      end
    end
  end
end
