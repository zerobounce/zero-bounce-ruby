# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'

RSpec.describe Zerobounce::BaseRequest do
  # Test protected helpers via send
  let(:strip_trailing_slashes) { described_class.method(:__root_without_trailing_slashes__) }
  let(:safe_file_path) { described_class.method(:__safe_file_path__) }

  describe '.__root_without_trailing_slashes__' do
    it 'returns the string unchanged when there is no trailing slash' do
      expect(strip_trailing_slashes.call('https://api.example.com')).to eq('https://api.example.com')
      expect(strip_trailing_slashes.call('')).to eq('')
    end

    it 'strips a single trailing slash' do
      expect(strip_trailing_slashes.call('https://api.example.com/')).to eq('https://api.example.com')
    end

    it 'strips multiple trailing slashes' do
      expect(strip_trailing_slashes.call('https://api.example.com///')).to eq('https://api.example.com')
      expect(strip_trailing_slashes.call('https://api.example.com//')).to eq('https://api.example.com')
    end

    it 'does not strip slashes in the middle of the URL' do
      url = 'https://api.example.com/v2/endpoint'
      expect(strip_trailing_slashes.call(url)).to eq(url)
    end

    it 'handles root URL with only slashes' do
      expect(strip_trailing_slashes.call('https://example.com///')).to eq('https://example.com')
    end

    it 'calls to_s on non-string root' do
      root = Class.new { def to_s; 'https://api.example.com/'; end }.new
      expect(strip_trailing_slashes.call(root)).to eq('https://api.example.com')
    end
  end

  describe '.__safe_file_path__' do
    it 'raises ArgumentError when filepath is nil' do
      expect { safe_file_path.call(nil) }.to raise_error(ArgumentError, 'File path is required')
    end

    it 'raises ArgumentError when filepath is empty string' do
      expect { safe_file_path.call('') }.to raise_error(ArgumentError, 'File path is required')
    end

    it 'raises when filepath is only whitespace' do
      # Implementation does not strip; expand_path produces path that does not exist
      expect { safe_file_path.call("   \t ") }.to raise_error(Errno::ENOENT)
    end

    it 'raises ArgumentError for path traversal outside current directory' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          expect { safe_file_path.call('../../etc/passwd') }.to raise_error(ArgumentError, 'File path must be under the current directory')
          expect { safe_file_path.call('../other/file.csv') }.to raise_error(ArgumentError, 'File path must be under the current directory')
        end
      end
    end

    it 'raises ArgumentError when path resolves to a directory' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          FileUtils.mkdir_p('subdir')
          expect { safe_file_path.call('subdir') }.to raise_error(ArgumentError, 'File path must point to a regular file')
        end
      end
    end

    it 'raises Errno::ENOENT when file does not exist' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          expect { safe_file_path.call('nonexistent.csv') }.to raise_error(Errno::ENOENT)
        end
      end
    end

    it 'returns canonical path for a valid relative file under cwd' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          File.write('upload.csv', 'a,b')
          result = safe_file_path.call('upload.csv')
          expect(result).to eq(File.realpath('upload.csv'))
          expect(File.exist?(result)).to be true
          expect(File.file?(result)).to be true
        end
      end
    end

    it 'returns canonical path for a valid file in a subdirectory' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          FileUtils.mkdir_p('data')
          File.write('data/file.csv', 'x')
          result = safe_file_path.call('data/file.csv')
          expect(result).to eq(File.realpath('data/file.csv'))
          expect(File.file?(result)).to be true
        end
      end
    end

    it 'rejects path that expands outside cwd even if file does not exist' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          # Expanded path is outside dir; realpath would raise ENOENT, but we check expanded first
          outside = File.join(dir, '..', 'outside.csv')
          expect { safe_file_path.call(outside) }.to raise_error(ArgumentError, 'File path must be under the current directory')
        end
      end
    end

    it 'accepts path with . and returns canonical path' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          File.write('f.csv', 'x')
          result = safe_file_path.call('./f.csv')
          expect(result).to eq(File.realpath('f.csv'))
        end
      end
    end

    it 'calls to_s on non-string filepath' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          File.write('f.csv', 'x')
          pathlike = Class.new { def to_s; 'f.csv'; end }.new
          result = safe_file_path.call(pathlike)
          expect(result).to eq(File.realpath('f.csv'))
        end
      end
    end
  end
end
