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
