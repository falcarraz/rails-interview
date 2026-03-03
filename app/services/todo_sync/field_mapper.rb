module TodoSync
  class FieldMapper
    SEPARATOR = ": "

    def self.to_external_description(title, description)
      return title.to_s if description.blank?
      "#{title}#{SEPARATOR}#{description}"
    end

    def self.from_external_description(external_description)
      return { title: "", description: "" } if external_description.blank?

      parts = external_description.split(SEPARATOR, 2)

      if parts.length == 2
        { title: parts[0], description: parts[1] }
      else
        { title: external_description, description: "" }
      end
    end
  end
end
