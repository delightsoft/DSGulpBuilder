path = require 'path'
gutil = require 'gulp-util'
browserify = require 'browserify'
watchify = require 'watchify'
uglify = require 'gulp-uglify'
source = require 'vinyl-source-stream2'
rename = require 'gulp-rename'
jade = require 'gulp-jade'
through = require 'through2'
changed = require 'gulp-changed'

ngHtml2js = require 'gulp-ng-html2js'
concat = require 'gulp-concat'

minimatch = require 'minimatch'
ternaryStream = require 'ternary-stream'

preprocessPath = require '../common/preprocessPath'

{TaskBase, tooManyArgs, missingArg, unsupportedOption, invalidOptionType, handleErrors} = require '../common/TaskBase'

module.exports =

  class NgHtml2JS extends TaskBase

    constructor: ((task, @_src, opts) ->
      missingArg() if arguments.length == 1
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

      GLOBAL.gulp.task @_name, @_deps, ((callback) =>

        callback = @_setWatch callback, (=>
          GLOBAL.gulp.watch @_fixedSrc, [@_name]
          return)

        cnt = 0

        p = GLOBAL.gulp.src @_fixedSrc
        .pipe(through.obj((file, enc, cb) =>
          cnt++ # count found files
          cb null, if !@_singleFile && path.basename(file.path).indexOf('_') == 0 then null else file # skip files with name started with underscore
          return))
        .pipe(ternaryStream(((file) ->
          minimatch(file.relative, '**/*.+(jade|html)')),
          jade({locals: {dev: gutil.env.dev, min: if gutil.env.dev then '' else '.min'}})))
        .pipe(ngHtml2js(@_opts))
        .pipe(concat path.basename @_dest)
        .pipe(changed(path.dirname @_dest, hasChanged: changed.compareSha1Digest))
        .pipe(gulp.dest path.dirname @_dest)
        .on('error', handleErrors)
        .on 'end', (=>
          if cnt == 0
            gutil.log gutil.colors.red "Task '#{@_name}': Nothing is found for source '#{@_src}' (#{path.resolve process.cwd(), @_fixedSrc})"
          callback()
          return)
        return false)

      @_built = true
      return @_name)