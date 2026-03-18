module Figma
  class JsxCompiler
    class CompilationError < StandardError; end

    # Preferred: vendored binary (no Node.js required)
    VENDOR_ESBUILD_PATH = "vendor/bin/esbuild"
    # Legacy fallback: npm-installed binary
    NPM_ESBUILD_PATH = "node_modules/.bin/esbuild"

    def self.compile(jsx_code)
      new.compile(jsx_code)
    end

    def self.compile_batch(snippets)
      new.compile_batch(snippets)
    end

    def compile(jsx_code)
      return "" if jsx_code.blank?

      require "open3"

      safe_input = jsx_code.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")

      stdout, stderr, status = Open3.capture3(
        esbuild_path,
        "--loader=jsx",
        "--jsx=transform",
        "--target=es2020",
        stdin_data: safe_input
      )

      unless status.success?
        raise CompilationError, "esbuild failed: #{stderr}"
      end

      stdout.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
    end

    # Batch-compile multiple JSX snippets in a single esbuild invocation.
    # Takes [{ key:, code: }], returns { key => compiled_code }.
    def compile_batch(snippets)
      return {} if snippets.empty?

      require "tmpdir"
      require "open3"

      Dir.mktmpdir("esbuild_batch") do |dir|
        input_dir = File.join(dir, "in")
        output_dir = File.join(dir, "out")
        FileUtils.mkdir_p(input_dir)
        FileUtils.mkdir_p(output_dir)

        snippets.each do |snippet|
          safe_code = snippet[:code].to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
          File.write(File.join(input_dir, "#{snippet[:key]}.jsx"), safe_code)
        end

        stdout, stderr, status = Open3.capture3(
          esbuild_path,
          "--outdir=#{output_dir}",
          "--loader=jsx",
          "--jsx=transform",
          "--target=es2020",
          *Dir[File.join(input_dir, "*.jsx")]
        )

        if status.success?
          results = {}
          snippets.each do |snippet|
            out_file = File.join(output_dir, "#{snippet[:key]}.js")
            if File.exist?(out_file)
              results[snippet[:key]] = File.read(out_file).encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
            end
          end
          results
        else
          # Fallback: compile each snippet individually
          Rails.logger.warn("Batch esbuild failed (#{stderr.truncate(200)}), falling back to individual compilation")
          results = {}
          snippets.each do |snippet|
            results[snippet[:key]] = compile(snippet[:code])
          rescue CompilationError => e
            Rails.logger.error("Individual compilation failed for #{snippet[:key]}: #{e.message}")
            results[snippet[:key]] = nil
          end
          results
        end
      end
    end

    def compile_component(jsx_code, component_name)
      return "" if jsx_code.blank?

      code = jsx_code.dup
      code = code.gsub(/^import [^\n]+\n/, "")
      code = code.gsub(/^export default [^\n]+\n?/, "")
      code = code.gsub(/^export /, "")

      compile(code)
    end

    private

    def esbuild_path
      # Try vendored binary first
      vendor_path = Rails.root.join(VENDOR_ESBUILD_PATH)
      return vendor_path.to_s if File.executable?(vendor_path)

      # Fall back to npm binary
      npm_path = Rails.root.join(NPM_ESBUILD_PATH)
      return npm_path.to_s if File.executable?(npm_path)

      raise CompilationError,
        "esbuild not found. Run: bin/setup_esbuild (or npm install esbuild)"
    end
  end
end
