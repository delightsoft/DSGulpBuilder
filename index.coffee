# TODO: Make gulp.watch watching new files (switch to https://www.npmjs.com/package/gulp-watch)
# TODO: Jasmine task should block dependets
# TODO: Jasmine task should take source files from dependent tasks
# TODO: Optimize watch strategy - i.e. ngJade2js should not watch by itself if takes sources from the same folder as Browserify, which has ngJade2js task in dependencies.  Otherwise ngJade2js gets called twice

require './common/polyfills' # must go first
GLOBAL.R = require 'ramda'

{TaskBase} = require './common/TaskBase'
Task = require './common/Task'

turnTasksToNames = ((tasks) ->
  if (ok = Array.isArray tasks)
    for task, i in tasks
      if Array.isArray task # inner array
        turnTasksToNames task
      else if !(ok = typeof task == 'string') # not a string
        break unless (ok = task instanceof TaskBase)
        tasks[i] = task._build()
  throw new Error 'Invalid list of tasks' if !ok
  return tasks)

module.exports = ((gulp) ->

  GLOBAL.gulp = gulp
  gutil = require 'gulp-util'
  gulpsync = require('gulp-sync')(gulp)

  return {

    task: ((taskname, deps) -> new Task(taskname, deps))

    async: ((tasks, name) -> gulpsync.async turnTasksToNames(tasks), name)

    sync: ((tasks, name) -> gulpsync.sync turnTasksToNames(tasks), name)

    go: ((tasks) ->
      tasks = turnTasksToNames(tasks)
      console.info 'TaskBase._watchTask: ', TaskBase._watchTask
      if TaskBase._watchTask
        gulp.task 'watch', TaskBase._watchTask
        tasks.push 'watch'
      console.info 'tasks: ', tasks
      gulp.task 'default', tasks)

    gutil: gutil
  })
