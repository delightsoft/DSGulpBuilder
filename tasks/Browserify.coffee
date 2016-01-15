browserify = require 'browserify'
watchify = require 'watchify'
uglify = require 'gulp-uglify'
source = require 'vinyl-source-stream2'
rename = require 'gulp-rename'
changed = require 'gulp-changed'

{TaskBase, tooManyArgs, missingArg, unsupportedOption, invalidOptionType} = require '../common/TaskBase'

module.exports =

  class Browserify extends TaskBase

    constructor: ((task, @_src, opts) ->
      missingArg() if arguments.length == 1
      tooManyArgs() if arguments.length > 3
      TaskBase.call @, task
      throw new Error 'Invalid source file name (1st argument)' unless typeof @_src == 'string' && @_src != ''
      @_minimize = true
      @_debug = true
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
              else unsupportedOption k
        throw new Error 'Invalid options (2nd argument)' unless ok
      return)

    @destMixin()

    _build: (->
      return @_name if @_built

      @_mixinAssert?()

      TaskBase.addToWatch (=>
        GLOBAL.gulp.watch @_src, [@_name]
        return)

      GLOBAL.gulp.task @_name, @_deps, ((cb) =>

        # Note: https://github.com/substack/node-browserify/wiki/list-of-transforms

        bundler = browserify(
          cache: {}
          packageCache: {}
          fullPaths: false
          extensions: ['.coffee']
          entries: @_src
          debug: false)
        bundler = watchify(bundler, ignoreWatch: true)
        .on "update", (=> GLOBAL.gulp.start @_name; return)
        .transform(require('coffeeify'))

        p = bundler.bundle()
        p = @_onError p, 'finish'

        if @_debug
          p = p.pipe(source(@_src)) # for some reason, bundler do not translate source name from 'entries' parameter
          .pipe(rename(extname: '.js'))
          .pipe(changed(@_destFirstLocation, hasChanged: changed.compareSha1Digest))
          p = @_dest(p)

        if @_minimize
          p = p.pipe(rename(extname: '.min.js')).pipe(uglify())
          p = p.pipe(changed(@_destFirstLocation, hasChanged: changed.compareSha1Digest)) if !@_debug
          p = @_dest(p)

        p = @_endPipe p, 'finish', cb

        return false)

      @_built = true
      return @_name)