module RorVsWild
  module Local
    class Middleware
      include ERB::Util

      attr_reader :app, :config

      def initialize(app, config)
        @app, @config = app, config
      end

      def call(env)
        env["REQUEST_URI"] == "/rorvswild" ? standalone_profiler(env) : embed_profiler(env)
      end

      def standalone_profiler(env)
        html = "<!DOCTYPE html>\n<html><head></head><body></body></html>"
        [200, {"Content-Type:" => "text/html; charset=utf-8"}, StringIO.new(inject_into(html))]
      end

      def embed_profiler(env)
        status, headers, body = app.call(env)
        if status >= 200 && status < 300 && headers["Content-Type"] && headers["Content-Type"].include?("text/html")
          if headers["Content-Encoding"]
            log_incompatible_middleware_warning
          else
            body.each { |string| inject_into(string) }
            headers["Content-Length"] = body.map(&:bytesize).reduce(0, :+).to_s if headers["Content-Length"]
          end
        end
        [status, headers, body]
      end

      def inject_into(html)
        markup = html_markup(RorVsWild.agent.queue.requests).encode(html.encoding)
        style = "<style type='text/css'> #{concatenate_stylesheet}</style>".encode(html.encoding)

        if index = html.index("</body>")
          html.insert(index, markup)
        end
        if index = html.index("</head>")
          html.insert(index, style)
        end
        html
      rescue Encoding::UndefinedConversionError => ex
        log_incompatible_encoding_warning(ex)
      end

      LOCAL_FOLDER = File.expand_path(File.dirname(__FILE__))
      JS_FOLDER = File.join(LOCAL_FOLDER, "javascript")
      CSS_FOLDER = File.join(LOCAL_FOLDER, "stylesheet")
      JS_FILES = ["vendor/mustache.js", "vendor/barber.js", "vendor/prism.js", "local.js"]
      CSS_FILES = ["vendor/prism.css", "local.css"]

      def html_markup(data)
        html = File.read(File.join(LOCAL_FOLDER, "local.html"))
        html % {data: html_escape(data.to_json), javascript_source: concatenate_javascript}
      end

      def concatenate_javascript
        concatenate_assets(JS_FOLDER, JS_FILES)
      end

      def concatenate_stylesheet
        concatenate_assets(CSS_FOLDER, CSS_FILES)
      end

      def concatenate_assets(directory, files)
        files.map { |file| File.read(File.join(directory, file)) }.join("\n")
      end

      def log_incompatible_middleware_warning
        RorVsWild.logger.warn("RorVsWild::Local cannot be embeded into your HTML page because of compression." +
          " Try to disable Rack::Deflater in development only." +
          " In the meantime just visit the /rorvswild page to see the profiler.")
      end

      def log_incompatible_encoding_warning(exception)
        RorVsWild.logger.warn("RorVsWild::Local cannot be embeded into your HTML page because of incompatible #{exception.message}." +
          " However you can just visit the /rorvswild page to see the profiler.")
      end
    end
  end
end
