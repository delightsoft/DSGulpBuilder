path = require 'path'
browserify = require 'browserify'
watchify = require 'watchify'
uglify = require 'gulp-uglify'
source = require 'vinyl-source-stream2'
rename = require 'gulp-rename'
sass = require 'gulp-sass'
cssNano = require 'gulp-cssnano'
through = require 'through2'
autoprefixer = require 'gulp-autoprefixer'
changed = require 'gulp-changed'

preprocessPath = require '../common/preprocessPath'

{TaskBase, tooManyArgs, missingArg, unsupportedOption, invalidOptionType} = require '../common/TaskBase'

module.exports =

  class Sass extends TaskBase

    constructor: ((task, @_src, opts) ->
      missingArg() if arguments.length == 1
      tooManyArgs() if arguments.length > 3
      TaskBase.call @, task
      throw new Error 'Invalid source file name (1st argument)' unless typeof @_src == 'string' && @_src != ''
      {path: @_fixedSrc, single: @_singleFile} = preprocessPath @_src, "**/*.sass"
      @_minimize = true
      @_debug = true
      @_includePaths = null
      if arguments.length > 2
        if (ok = typeof opts == 'object')
          for k, v of opts
            switch k
              when 'minimize'
                invalidOptionType k, 'boolean' unless typeof v == 'boolean'
                @_minimize = v
              when 'debug'
                invalidOptionType k, 'boolean' unless typeof v == 'boolean'
                @_debug = v
              when 'includePaths'
                for s in (if Array.isArray v then v else [v])
                  break unless (ok = typeof v == 'string')
                invalidOptionType k, 'string or array of strings' unless ok
                @_includePaths = v
              else unsupportedOption k
        throw new Error 'Invalid options (2nd argument)' unless ok
      return)

    @destMixin()

    _build: (->
      return @_name if @_built

      @_mixinAssert?()

      watchList = [@_fixedSrc]
      if @_includePaths
        for v in @_includePaths
          watchList.push "#{path.dirname(v)}/**/*.sass"

      TaskBase.addToWatch (=>
        GLOBAL.gulp.watch watchList, [@_name]
        return)

      GLOBAL.gulp.task @_name, @_deps, ((cb) =>

        sassOpts =
          sourceComments: "map"
          # imagePath: "/images" # Used by the image-url helper
          indentedSyntax: true

        sassOpts.includePaths = @_includePaths if @_includePaths

        p = GLOBAL.gulp.src @_fixedSrc
        p = @_countFiles p
        p = p.pipe(sass(sassOpts))        
        p = p.pipe(autoprefixer(browsers: ["last 10 version"]))
        p = @_onError p, 'finish'

        if @_debug
          p.pipe(changed(@_destFirstLocation, hasChanged: changed.compareSha1Digest))
          p = @_dest p

        if @_minimize
          p = p.pipe(cssNano())
          .pipe(rename(extname: '.min.css'))
          p = p.pipe(changed(@_destFirstLocation, hasChanged: changed.compareSha1Digest)) if !@_debug
          p = @_dest p

        p = @_endPipe p, 'finish', cb
        
        return false)

      @_built = true
      return @_name)