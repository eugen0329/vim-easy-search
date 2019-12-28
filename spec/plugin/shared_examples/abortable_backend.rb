# frozen_string_literal: true

RSpec.shared_examples 'an abortable backend' do |backend|
  let(:adapter) { 'ag' }
  let(:search_string) { '550e8400-e29b-41d4-a716-446655440000' }
  let(:out) { 'win' }
  let(:empty_cwd_for_infinite_search) { nil }

  around do |example|
    esearch.configure!(backend: backend, adapter: adapter, out: out)
    esearch.configuration.adapter_bin = "sh #{Configuration.bin_dir}/search_in_infinite_random_stdin.sh #{adapter}"
    expect(ps_commands).not_to include(search_string) # prevent false positive results

    example.run

    esearch.close_search!
    `ps -A -o pid,command | grep #{search_string} | grep -v grep | awk '{print $1}' | xargs kill -s KILL`
    expect { !ps_commands.include?(search_string) }.to become_true_within(10.seconds) # verify teardown is done
    esearch.configuration.adapter_bin = adapter
  end

  context '#out#win' do
    let(:out) { 'win' }

    it 'aborts on bufdelete' do
      esearch.search!(search_string, cwd: empty_cwd_for_infinite_search)

      expect(esearch).to have_search_started
      expect { ps_commands.include?(search_string) }.to become_true_within(10.seconds)
      expect(esearch).to have_search_freezed

      delete_current_buffer
      expect { !ps_commands.include?(search_string) }.to become_true_within(10.seconds)
    end

    it 'aborts on search restart' do
      2.times do
        esearch.search!(search_string, cwd: empty_cwd_for_infinite_search)

        expect(esearch).to have_search_started
        expect { ps_commands.include?(search_string) }.to become_true_within(10.seconds)
        expect(esearch).to have_search_freezed
      end

      expect { ps_commands_without_sh.scan(/#{search_string}/).count == 1 }
        .to become_true_within(10.seconds)
    end
  end

  xcontext '#out#qflist' do
    let(:out) { 'qflist' }

    it 'aborts on bufdelete' do
      esearch.search!(search_string, cwd: empty_cwd_for_infinite_search)
      wait_for_qickfix_enter
      expect { ps_commands.include?(search_string) }.to become_true_within(10.seconds)
      expect(esearch).to have_search_freezed
      expect { ps_commands.include?(search_string) }.to become_true_within(10.seconds)

      delete_current_buffer
      expect { !ps_commands.include?(search_string) }.to become_true_within(10.seconds)
    end

    it 'aborts on search restart' do
      2.times do
        esearch.search!(search_string, cwd: empty_cwd_for_infinite_search)
        wait_for_qickfix_enter
        expect { ps_commands.include?(search_string) }.to become_true_within(10.seconds)
        expect(esearch).to have_search_freezed
      end

      expect { ps_commands_without_sh.scan(/#{search_string}/).count == 1 }
        .to become_true_within(10.seconds)
    end
  end

  include_context 'dumpable'
end
