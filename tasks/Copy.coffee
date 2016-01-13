path = require 'path'
gutil = require 'gulp-util'
rename = require 'gulp-rename'
through = require 'through2'
changed = require 'gulp-changed'

preprocessPath = require '../common/preprocessPath'

{TaskBase, tooManyArgs, missingArg, unsupportedOption, invalidOptionType, handleErrors} = require '../common/TaskBase'

module.exports =

  class Copy extends TaskBase

    constructor: ((task, @_src) ->
      missingArg() if arguments.length == 1
      tooManyArgs() if arguments.length > 2
      TaskBase.call @, task
      throw new Error 'Invalid source file or directory name (1st argument)' unless typeof @_src == 'string' && @_src != ''
      {path: @_fixedSrc, single: @_singleFile} = preprocessPath @_src, "**/*"
      return)

    @destMixin()

    _build: (->
      return @_name if @_built

      @_mixinAssert?()

      GLOBAL.gulp.task @_name, @_deps, ((callback) =>

        callback = @_setWatch callback, (=>
          GLOBAL.gulp.watch @_fixedSrc, [@_name]
          return)

        cnt = 0

        p = GLOBAL.gulp.src @_fixedSrc
        .pipe(through.obj((file, enc, cb) =>
          cnt++ # count found files
          cb null, file
          return))
        .pipe(changed(@_destFirstLocation))

        p = @_dest(p)

        p.on("error", handleErrors)
        .on 'end', (=>
          if cnt == 0
            gutil.log gutil.colors.red "Task '#{@_name}': Nothing is found for source '#{@_src}' (#{path.resolve process.cwd(), @_fixedSrc})"
          callback()
          return)
        return false)

      @_built = true
      return @_name)