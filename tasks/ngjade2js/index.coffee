path = require 'path'
gutil = require 'gulp-util'
jade = require 'gulp-jade'
changed = require 'gulp-changed'

ngHtml2js = require 'gulp-ng-html2js'
concat = require 'gulp-concat'

minimatch = require 'minimatch'
ternaryStream = require 'ternary-stream'

module.exports = (DSGulpBuilder) ->

  {invalidArg, tooManyArgs, missingArg, unsupportedOption, invalidOptionType, preprocessPath} = TaskBase = DSGulpBuilder.TaskBase

  class NgJade2JS extends TaskBase

    constructor: ((task, @_src, opts) ->
      missingArg() if arguments.length < 2
      tooManyArgs() if arguments.length > 3
      TaskBase.call @, task
      @_dest = null
      throw new Error 'Invalid source file or directory name (1st argument)' unless typeof @_src == 'string' && @_src != ''
      @_opts = opts ?= {}
      opts.moduleName ?= 'ngTemplates'
      opts.prefix ?= ''
      {path: @_fixedSrc, single: @_singleFile} = preprocessPath @_src, '**/*.+(jade|html)'
      return)

    dest: ((dest) ->
      invalidOptionType('dest', 'string') unless typeof dest == 'string' && dest.trim() != ''
      @_dest = dest
      return @)

    _build: (->
      return @_name if @_built

      if @_dest == null
        throw new Error "Task '#{@_name}': dest is not specified"

      TaskBase.addToWatch (=>
        GLOBAL.gulp.watch @_fixedSrc, [@_name]
        return)

      GLOBAL.gulp.task @_name, @_deps, ((cb) =>

        p = GLOBAL.gulp.src @_fixedSrc
        p = @_countFiles p
        p = p.pipe(ternaryStream(((file) ->
          minimatch(file.relative, '**/*.+(jade|html)')),
          jade({locals: {dev: gutil.env.dev, min: if gutil.env.dev then '' else '.min'}})))
        .pipe(ngHtml2js(@_opts))
        p = @_onError p, 'finish'
        p = p.pipe(concat path.basename @_dest)
        .pipe(changed(path.dirname @_dest, hasChanged: changed.compareSha1Digest))
        .pipe(gulp.dest path.dirname @_dest)

        p = @_endPipe p, 'finish', cb

        return false)

      @_built = true
      return @_name)

# ----------------------------

  DSGulpBuilder.Task::ngJade2JS = ->
    newInstance = Object.create(NgJade2JS::)
    args = [@]
    args.push arg for arg in arguments
    NgJade2JS.apply newInstance, args
    return newInstance

  return    