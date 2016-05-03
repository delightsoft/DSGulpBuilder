path = require 'path'
fs = require 'fs'
browserSync = require 'browser-sync'

{tooManyArgs, missingArg, unsupportedOption, invalidOptionType} = TaskBase = require '../common/TaskBase'

module.exports =

  class Browserify extends TaskBase

    constructor: ((task, @_src, opts) ->
      missingArg() if arguments.length < 2
      tooManyArgs() if arguments.length > 3
      TaskBase.call @, task
      throw new Error 'Invalid source file name (1st argument)' unless typeof @_src == 'string' && @_src != ''
      @_proxy = null
      @_port = 80
      @_debug = true
      if arguments.length > 2
        if (ok = typeof opts == 'object')
          for k, v of opts
            switch k
              when 'proxy'
                invalidOptionType k, 'string' unless typeof v == 'string'
                @_proxy = v
              when 'port'
                invalidOptionType k, 'number' unless typeof v == 'number'
                @_port = v
              when 'debug'
                invalidOptionType k, 'boolean' unless typeof v == 'boolean'
                @_debug = v
              else unsupportedOption k
        throw new Error 'Invalid options (2nd argument)' unless ok
      return)

    _build: (->
      return @_name if @_built

      if @_proxy
        config =
          port: @_port
          proxy: @_proxy
          middleware: ((req, res, next) ->
            console.log req.url
            next()
            return)
      else
        config =
          port: @_port
          server:
            # We're serving the src folder as well
            # for sass sourcemap linking
            baseDir: [@_src]
          files: [
            "#{@_src}/**"
            # Exclude Map files
            "!#{@_src}/**.map"
          ]
          middleware: ((req, res, next) =>
            if req.headers.accept?.indexOf('text/html') >= 0
              url = String req.url
              if url.indexOf('browser-sync-client') == -1
                if @_debug
                  console.log "url: #{url}"
                if url.charAt(url.length - 1) == '/'
                  url = url.substr(0, url.length - 1)
                try
                  stats = fs.statSync(filePath = path.join(@_src, url))
                  if stats.isDirectory()
                    try
                      stats = fs.statSync(filePath += '/index.html')
                      req.url = newUrl = "#{url}/index.html"
                    catch e # no index.html in this folder
                      req.url = newUrl = '/index.html' # default
                catch e # file not found
                  if url.substr(url.lastIndexOf(filePath, '/') + 1).indexOf('.') < 0 # path without extention, so let's try to add .html
                    try
                      stats = fs.statSync(filePath += '.html')
                      req.url = newUrl = "#{url}.html"
                    catch e # file not found, again
                      req.url = newUrl = '/index.html' # default
                  else
                    req.url = newUrl = '/index.html' # default
                if @_debug
                  console.log "new url: #{req.url}"
            next())

      GLOBAL.gulp.task @_name, (->
        browserSync config
        return)

      @_built = true
      return @_name)