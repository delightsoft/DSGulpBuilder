path = require 'path'
gutil = require 'gulp-util'
jasmine = require 'gulp-jasmine'
through = require 'through2'

preprocessPath = require '../common/preprocessPath'

{TaskBase, tooManyArgs, missingArg, unsupportedOption, invalidOptionType, handleErrors} = require '../common/TaskBase'

module.exports =

  class Jasmine extends TaskBase

    constructor: ((task, @_src, opts) ->
      missingArg() if arguments.length == 1
      tooManyArgs() if arguments.length > 3
      TaskBase.call @, task
      throw new Error 'Invalid source file or directory name (1st argument)' unless typeof @_src == 'string' && @_src != ''
      @_opts = opts
#      @_opts = R.merge {
#          includeStackTrace: true # Zork: It gives useless callstack - don't see test source line
##          isVerbose: false
##          config: ...goes to jasmine
#        }, (opts || {})

      {path: @_fixedSrc, single: @_singleFile} = preprocessPath @_src, '/**/*.*'
      return)

    watch: ((path) ->
      invalidOptionType('dest', 'string') unless typeof path == 'string' && path.trim() != ''
      @_watchSrc = path
      return @)

    _build: (->
      return @_name if @_built

      @_mixinAssert?()

      GLOBAL.gulp.task @_name, @_deps, ((callback) =>

        callback = @_setWatch callback, (=>
          GLOBAL.gulp.watch @_fixedSrc, [@_name]
          if @_watchSrc
            console.info '@_watchSrc: ', @_watchSrc
            GLOBAL.gulp.watch @_watchSrc, [@_name]
          return)

        cnt = 0

        p = GLOBAL.gulp.src @_fixedSrc # Note: _src is used intentionally
        .pipe(through.obj((file, enc, cb) =>
            cnt++ # count found files
            cb null, if !@_singleFile && path.basename(file.path).indexOf('_') == 0 then null else file # skip files with name started with underscore
            return))
        .pipe(jasmine(@_opts))
        .on('error', handleErrors)
        .on 'finish', (=> # Zork: Here I MUST use 'finish' (not 'end'), since I observer the following: without errors in test - I've got no 'end' event, but with errors - I've got TWO 'end's
          if cnt == 0
            gutil.log gutil.colors.red "Task '#{@_name}': Nothing is found for source '#{@_src}' (#{path.resolve process.cwd(), @_fixedSrc})"
          callback()
          return)

        return false)

      @_built = true
      return @_name)