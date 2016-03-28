path = require 'path'
gutil = require 'gulp-util'
through = require 'through2'
changed = require 'gulp-changed'

preprocessPath = require '../common/preprocessPath'

JasmineRunner = require 'jasmine'
JasmineReporter = require 'jasmine-terminal-reporter'

{TaskBase, tooManyArgs, missingArg, unsupportedOption, invalidOptionType} = require '../common/TaskBase'

gutil = require('gulp-util')

deleteRequireCache = (id) ->

  if !id or id.indexOf('node_modules') != -1
    return

  files = require.cache[id]

  if files != undefined
    Object.keys(files.children).forEach (file) ->
      deleteRequireCache files.children[file].id
      return

    delete require.cache[id]

  return

module.exports =

  class Jasmine extends TaskBase

    constructor: ((task, @_src, opts) ->
      missingArg() if arguments.length < 2
      tooManyArgs() if arguments.length > 3
      TaskBase.call @, task
      throw new Error 'Invalid source file or directory name (1st argument)' unless typeof @_src == 'string' && @_src != ''
      @_opts = opts
      {path: @_fixedSrc, single: @_singleFile} = preprocessPath @_src, '/**/*.+(coffee|litcoffee|coffee.md|js)'
      return)

    # If you want tests run be theirself (not as dependency), use this method to specify sources that are tested
    watch: ((path) ->
      invalidOptionType('dest', 'string or list of strings') unless Array.isArray(path) || (typeof path == 'string' && path.trim() != '')
      @_watchSrc = path
      return @)

    _build: (->
      return @_name if @_built

      @_mixinAssert?()

      TaskBase.addToWatch (=>
        GLOBAL.gulp.watch @_fixedSrc, [@_name]
        if @_watchSrc
          GLOBAL.gulp.watch @_watchSrc, [@_name]
        return)

      GLOBAL.gulp.task @_name, @_deps, ((taskCallback) =>

        p = GLOBAL.gulp.src @_fixedSrc # Note: _src is used intentionally
        p = @_countFiles p

        jasmine = new JasmineRunner

        if @_opts

          if @_opts.hasOwnProperty('timeout')
            jasmine.jasmine.DEFAULT_TIMEOUT_INTERVAL = @_opts.timeout

          if @_opts.hasOwnProperty('config')
            jasmine.loadConfig @_opts.config

        jasmine.addReporter new JasmineReporter

          isVerbose: if @_opts then @_opts.verbose else false

          showColors: if @_opts then @_opts.showColors else true

          includeStackTrace: if @_opts then @_opts.includeStackTrace else false

        p = p.pipe through.obj ((file, enc, cb) ->

          # get the cache object of the specs.js file,
          # delete it and its children recursively from cache
          resolvedPath = path.resolve(file.path)
          modId = require.resolve(resolvedPath)
          deleteRequireCache modId
          jasmine.addSpecFile resolvedPath
          cb()
          return),

        (cb) -> # flash
          try

            jasmine.onComplete =>
              taskCallback()
              return

            if jasmine.helperFiles
              jasmine.helperFiles.forEach (helper) ->
                resolvedPath = path.resolve(helper)
                modId = require.resolve(resolvedPath)
                deleteRequireCache modId
                return

            jasmine.execute()
          catch err
            cb new (gutil.PluginError)('DSGulpBuilder.jasmine', err, showStack: true)
          return

        return false)

      @_built = true
      return @_name)