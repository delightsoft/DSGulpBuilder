path = require 'path'
changed = require 'gulp-changed'

preprocessPath = require '../common/preprocessPath'

{tooManyArgs, missingArg, unsupportedOption, invalidOptionType} = TaskBase = require '../common/TaskBase'

module.exports =

  class Copy extends TaskBase

    constructor: ((task, @_src) ->
      missingArg() if arguments.length < 2
      tooManyArgs() if arguments.length > 2
      TaskBase.call @, task
      throw new Error 'Invalid source file or directory name (1st argument)' unless typeof @_src == 'string' && @_src != ''
      {path: @_fixedSrc, single: @_singleFile} = preprocessPath @_src, "**/*"
      return)

    @destMixin()

    _build: (->
      return @_name if @_built

      @_mixinAssert?()

      TaskBase.addToWatch (=>
        GLOBAL.gulp.watch @_fixedSrc, [@_name]
        return)

      GLOBAL.gulp.task @_name, @_deps, ((cb) =>

        p = GLOBAL.gulp.src @_fixedSrc
        p = @_countFiles p, true
        p = p.pipe(changed(@_destFirstLocation))
        p = @_dest p
        p = @_onError p, 'finish'
        p = @_endPipe p, 'finish', cb

        return false)

      @_built = true
      return @_name)