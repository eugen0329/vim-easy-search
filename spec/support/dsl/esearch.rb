# frozen_string_literal: true

# TODO: rewrite
module Support
  module DSL
    module ESearch
      def vim_let(var, value)
        vim.normal(":let #{var} = #{value}<Enter><Enter>")
      end
    end
  end
end
