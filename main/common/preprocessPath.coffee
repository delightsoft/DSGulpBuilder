fs = require 'fs'
path = require 'path'
glob = require 'glob'

# Actions:
#   1. Determine the type of path:
#        - specific file
#        - path with a mask
#        - folder
#        ...or throw a Error
#   2. Checks presents of the folder.  Throw Error if the folder is missing
#   3. Returns
#        - gulp path, adding default mask for the case of just a folder
#        - flag, that path specifies just a single file

module.exports = ((gulpPath, defaultMask) ->
  throw Error 'invalid 1st arg' unless typeof gulpPath == 'string'
  throw Error 'invalid 2nd arg' unless arguments.length == 1 || typeof defaultMask == 'string'
  throw Error 'too many arguments' unless arguments.length <= 2

  gulpPath = gulpPath.substr n + 1 if 0 <= (n = gulpPath.indexOf '/') < 2 # ensure, what gulp.watch will see new added files

  if glob.hasMagic gulpPath
    return {path: gulpPath, single: false}

  fullPath = path.resolve (cwd = process.cwd()), gulpPath # ensure, what gulp.watch will see new added files

  gulpPath = path.relative cwd, fullPath

  try
    if (stat = fs.statSync fullPath).isDirectory()
      pathWithMask =
        (if gulpPath.charAt(gulpPath.length - 1) != '/' then gulpPath else gulpPath.substr 0, gulpPath.length - 1) +
        (if defaultMask then (if defaultMask.charAt(0) == '/' then defaultMask else '/' + defaultMask) else '/**/*')
      return {path: pathWithMask, single: false, missing: false}
  catch e # will happend if directory or file is missing.  Will not process this here
    return {path: gulpPath, single: false, missing: true}

  return {path: gulpPath, single: true, missing: false})
