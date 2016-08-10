path = require 'path'
gutil = require 'gulp-util'
jade = require 'gulp-jade'
through = require 'through2'
changed = require 'gulp-changed'
minimatch = require 'minimatch'
ternaryStream = require 'ternary-stream'

module.exports = (DSGulpBuilder) ->

  {invalidArg, tooManyArgs, missingArg, unsupportedOption, invalidOptionType, preprocessPath} = TaskBase = DSGulpBuilder.TaskBase

  class Jade extends TaskBase

    constructor: (task, @_src, opts) ->
      missingArg() if arguments.length < 2
      tooManyArgs() if arguments.length > 3
      super task
      throw new Error 'Invalid source file or directory name (1st argument)' unless typeof @_src == 'string' && @_src != ''
      {path: @_fixedSrc, single: @_singleFile} = preprocessPath @_src, "**/*.+(jade|html)"
      if arguments.length > 2
        if (ok = typeof opts == 'object')
          for k, v of opts
            switch k
              when 'locals'
                invalidOptionType k, 'object' unless typeof v == 'object' && v != null
                @_locals = v
              else unsupportedOption k
        throw new Error 'Invalid options (2nd argument)' unless ok

    @destMixin()

    duplicate: (dupMap) ->
      missingArg() if arguments.length < 1
      tooManyArgs() if arguments.length > 1
      throw new Error 'duplicate() 1: Invalid argument dupMap' unless typeof dupMap == 'object' && dupMap != null
      for origFilename, toFilename of dupMap
        if typeof toFilename == 'string'
          dupMap[origFilename] = [toFilename]
        else
          throw new Error 'duplicate() 2: Invalid argument dupMap' unless Array.isArray toFilename
          for v in toFilename when not typeof v == 'string'
            throw new Error 'duplicate() 3: Invalid argument dupMap'
      @_dupMap = dupMap
      @ # duplicate:

    _build: ->
      return @_name if @_built

      @_mixinAssert?()

      TaskBase.addToWatch (=>
        GLOBAL.gulp.watch @_fixedSrc, [@_name]
        return)

      GLOBAL.gulp.task @_name, @_deps, (cb) =>

        locals =
          dev: !!gutil.env.dev
          min: if gutil.env.dev then '' else '.min'

        if @_locals then locals[k] = v for k, v in @_locals

        p = GLOBAL.gulp.src @_fixedSrc
        p = @_countFiles p
        p = p.pipe(ternaryStream(((file) ->
              minimatch(file.relative, '**/*.jade')),
            jade(locals: locals)))
        p = @_onError p, 'finish'

        if (dupMap = @_dupMap)
          p = p.pipe through.obj (file, enc, cb) ->
            if dupMap.hasOwnProperty file.relative
              for toFile in dupMap[file.relative]
                clone = file.clone()
                clone.path = path.join file.base, toFile
                @push clone
            cb null, file
            return

        p = p.pipe changed @_destFirstLocation, hasChanged: changed.compareSha1Digest
        p = @_dest(p)
        p = @_endPipe p, 'finish', cb

        return false # (cb) =>

      @_built = true
      return @_name # _build:

# ----------------------------

  DSGulpBuilder.Task::jade = ->
    newInstance = Object.create(Jade::)
    args = [@]
    args.push arg for arg in arguments
    Jade.apply newInstance, args
    return newInstance

  return    