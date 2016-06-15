fs = require 'fs'
rimraf = require 'rimraf'

{tooManyArgs, missingArg, unsupportedOption, invalidOptionType} = TaskBase = require '../common/TaskBase'

module.exports =

  class ClearFolder extends TaskBase

    constructor: ((task, @_folder) ->
      missingArg() if arguments.length < 2
      tooManyArgs() if arguments.length > 2
      TaskBase.call @, task
      @_keep = []
      throw new Error 'Invalid folder name (1st argument)' unless typeof @_folder == 'string' && @_folder != ''
      return)

    keep: ((fileOrFolderNames) ->
      @_isAlreadyBuilt()

      missingArg() if arguments.length == 0
      tooManyArgs() if arguments.length > 1
      if (ok = typeof fileOrFolderNames == 'string')
        @_keep.push fileOrFolderNames
      else if Array.isArray fileOrFolderNames
        ok = true
        for name in fileOrFolderNames
          break if !(ok = typeof name == 'string')
          @_keep.push name
      throw new Error 'First argument must be either string or list of strings' if !ok

      return @)

    _build: (->
      return @_name if @_built

      GLOBAL.gulp.task @_name, @_deps, ((callback) =>
        if @_keep.length > 0
          fs.readdir @_folder, ((err, files) =>
            if err
              if err.message.startsWith 'ENOENT: no such file or directory'
                callback()
                return
              throw new Error err
            n = 0
            for file in files when not (file in @_keep)
              do (file) =>
                n++
                rimraf "#{@_folder}/#{file}", (->
                  callback() if --n == 0
                  return)
            callback() if n == 0
            return)
        else rimraf @_folder, callback
        return false)

      @_built = true
      return @_name)