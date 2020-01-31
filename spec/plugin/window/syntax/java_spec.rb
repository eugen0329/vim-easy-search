# frozen_string_literal: true

require 'spec_helper'
require_relative 'setup_syntax_testing_shared_context'

describe 'esearch window context syntax' do
  include Helpers::FileSystem
  include Helpers::WindowSyntaxContext

  describe 'java' do
    let(:source_file_content) do
      <<~SOURCE
        if
        else
        switch

        while
        for
        do

        true
        false

        "string"
        "str with escape\\n"
        "long string#{'.' * 100}"

        null

        "unterminated string
        `unterminated raw string

        this
        super

        // comment line
        /* comment block */
        /* long comment #{'.' * 100}*/

        new
        instanceof

        return

        static
        synchronized
        transient
        volatile
        final
        strictfp
        serializable

        throw
        try
        catch
        finally

        assert

        extends
        implements
        interface
        enum

        public
        protected
        private
        abstract
      SOURCE
    end
    let(:source_file) { file(source_file_content, 'main.java') }

    include_context 'setup syntax testing'

    it do
      is_expected.to have_highligh_aliases(
        word('if')           => %w[es_javaConditional Conditional],
        word('else')         => %w[es_javaConditional Conditional],
        word('switch')       => %w[es_javaConditional Conditional],

        word('while')        => %w[es_javaRepeat Repeat],
        word('for')          => %w[es_javaRepeat Repeat],
        word('do')           => %w[es_javaRepeat Repeat],

        word('true')         => %w[es_javaBoolean Boolean],
        word('false')        => %w[es_javaBoolean Boolean],

        region('"string"')               => %w[es_javaString String],
        region('"str with escape\\\\n"') => %w[es_javaString String],
        region('"long string[^"]\\+$')   => %w[es_javaString String],

        word('null')         => %w[es_javaConstant Constant],

        region('"unterminated string')       => %w[es_javaString String],

        word('this')         => %w[es_javaTypedef Typedef],
        word('super')        => %w[es_javaTypedef Typedef],

        region('// comment line')            => %w[es_javaComment Comment],
        region('/\* comment block')          => %w[es_javaComment Comment],
        region('/\* long comment')           => %w[es_javaComment Comment],

        word('new')          => %w[es_javaOperator Operator],
        word('instanceof')   => %w[es_javaOperator Operator],

        word('return')       => %w[es_javaStatement Statement],

        word('static')       => %w[es_javaStorageClass StorageClass],
        word('synchronized') => %w[es_javaStorageClass StorageClass],
        word('transient')    => %w[es_javaStorageClass StorageClass],
        word('volatile')     => %w[es_javaStorageClass StorageClass],
        word('final')        => %w[es_javaStorageClass StorageClass],
        word('strictfp')     => %w[es_javaStorageClass StorageClass],
        word('serializable') => %w[es_javaStorageClass StorageClass],

        word('throw')        => %w[es_javaExceptions Exception],
        word('try')          => %w[es_javaExceptions Exception],
        word('catch')        => %w[es_javaExceptions Exception],
        word('finally')      => %w[es_javaExceptions Exception],

        word('assert')       => %w[es_javaAssert Statement],

        word('extends')      => %w[es_javaClassDecl javaStorageClass],
        word('implements')   => %w[es_javaClassDecl javaStorageClass],
        word('interface')    => %w[es_javaClassDecl javaStorageClass],
        word('enum')         => %w[es_javaClassDecl javaStorageClass],

        word('public')       => %w[es_javaScopeDecl javaStorageClass],
        word('protected')    => %w[es_javaScopeDecl javaStorageClass],
        word('private')      => %w[es_javaScopeDecl javaStorageClass],
        word('abstract')     => %w[es_javaScopeDecl javaStorageClass]
      )
    end
  end
end
