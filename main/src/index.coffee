gutil = require 'gulp-util'
TaskBase = require './common/TaskBase'
Task = require './common/Task'
{StubTask} = require './externalTasks'

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

module.exports = (gulp, noWatchFunc) ->

  GLOBAL.gulp = gulp
  gutil = require 'gulp-util'
  gulpsync = require('gulp-sync')(gulp)

  DSGulpBuilder = {

    TaskBase: TaskBase

    Task: Task

    task: ((taskname, deps) -> new Task(taskname, deps))

    async: ((tasks, name) -> if Task.missingModules.length == 0 then gulpsync.async turnTasksToNames(tasks), name)

    sync: ((tasks, name) -> if Task.missingModules.length == 0 then gulpsync.sync turnTasksToNames(tasks), name)

    go: ((tasks) ->

      if Task.missingModules.length > 0
        if Task.missingModules.length == 1
          console.error gutil.colors.red "To proceed you need to install an optional module.  Please, run:"
          console.error gutil.colors.yellow "npm install #{Task.missingModules[0]} --save-dev"
        else
          console.error gutil.colors.red "To proceed you need to install few optional modules.  Please, run:"
          Task.missingModules.sort()
          console.error gutil.colors.yellow "npm install #{Task.missingModules.join ' '} --save-dev"
        return

      tasks = turnTasksToNames(tasks)
      if (!noWatchFunc || !noWatchFunc()) && TaskBase._watchTask
        gulp.task 'watch', TaskBase._watchTask
        tasks.push 'watch'
      gulp.task 'default', tasks)

    gutil: gutil

    errorHandler: (taskName) ->
      throw new Error 'Invalid argument \'taskName\'' unless typeof taskName == 'string' && taskName.length > 0
      -> # pipe.on 'error' handler
        notify.onError
          title: "Task '#{taskName}': Error"
          message: '<%= error %>'
        .apply @, Array::slice.call arguments
        return
  }
  
  Task::_DSGulpBuilder = DSGulpBuilder 
  
  DSGulpBuilder # module.exports = (gulp) ->
