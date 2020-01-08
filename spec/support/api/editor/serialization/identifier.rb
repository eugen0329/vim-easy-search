# frozen_string_literal: true

API::Editor::Serialization::Identifier = Struct.new(:string_representation) do
  alias_method :to_s, :string_representation
end
