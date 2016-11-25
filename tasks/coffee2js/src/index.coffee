path = require 'path'
coffee = require 'gulp-coffee'
changed = require 'gulp-changed'

minimatch = require 'minimatch'
ternaryStream = require 'ternary-stream'

module.exports = (DSGulpBuilder) ->

  {invalidArg, tooManyArgs, missingArg, unsupportedOption, invalidOptionType, preprocessPath} = TaskBase = DSGulpBuilder.TaskBase

  class Coffee2JS extends TaskBase

    constructor: ((task, @_src) ->
      missingArg() if arguments.length < 2
      tooManyArgs() if arguments.length > 2
      TaskBase.call @, task
      throw new Error 'Invalid source file or directory name (1st argument)' unless typeof @_src == 'string' && @_src != ''
      {path: @_fixedSrc, single: @_singleFile} = preprocessPath @_src, '**/*.+(coffee|litcoffee|coffee.md|js)'
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
        p = p.pipe(ternaryStream(((file) ->
            minimatch(file.relative, '**/*.+(coffee|litcoffee|coffee.md)')),
          coffee(bare: true)))
        p = @_onError p, 'finish'
        p = p.pipe(changed(@_destFirstLocation))
        p = @_dest(p)
        p = @_endPipe p, 'finish', cb

        return false)

      @_built = true
      return @_name)

  # ----------------------------

  DSGulpBuilder.Task::coffee2js = ->
    newInstance = Object.create(Coffee2JS::)
    args = [@]
    args.push arg for arg in arguments
    Coffee2JS.apply newInstance, args
    return newInstance

  return