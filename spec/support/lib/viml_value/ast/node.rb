# frozen_string_literal: true

# Defined to be compliant with ast gem, but without introducing it as a
# dependency as we don't use most of it's features
VimlValue::AST::Node = Struct.new(:type, :children)