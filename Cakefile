fs         = require 'fs'
{exec}     = require 'child_process'
util       = require 'util'

appFiles  = [
    'src/annotate.coffee'
    'src/annotationSelector.coffee'
    'src/stanbolEnhancementAPI.coffee'
]
justchanged = null

task 'watch', 'Watch prod source files and build changes', ->
    invoke 'build'
    util.log "Watching for changes in #{appFiles.join ', '}"

    for file in appFiles then do (file) ->
        fs.watchFile file, (curr, prev) ->
            if +curr.mtime isnt +prev.mtime
                util.log "Saw change in #{file}"
                justchanged = file
                invoke 'build'

task 'build', 'Build single application file from source files', ->
    # invoke 'coffeeFiles'
    appContents = new Array remaining = appFiles.length
    for file, index in appFiles then do (file, index) ->
        fs.readFile file, 'utf8', (err, fileContents) ->
            throw err if err
            appContents[index] = fileContents
            process() if --remaining is 0
    process = ->
        fs.writeFile 'lib/annotate.coffee', appContents.join('\n\n'), 'utf8', (err) ->
            throw err if err
            cmd = 'coffee -c -o lib lib/annotate.coffee'
            util.log "executing #{cmd}"
            exec cmd, (err, stdout, stderr) ->
                if err
                    fs.unlink 'lib/annotate.coffee', (err) ->
                    justchanged = appFiles.join " " unless justchanged
                    util.log "Error compiling coffee file. Last changed: #{justchanged}"
                    exec "coffee --compile #{justchanged}", (err, stdout, stderr) ->
                        util.error stderr
                        fs.unlink file.replace /.coffee$/, ".js" for file in appFiles
                else
                    util.log "compile ok"
                    fs.unlink 'lib/annotate.coffee', (err) ->
                        if err
                            util.log 'Couldn\'t delete the lib/annotate.coffee file/'
                        util.log 'Done building coffee file.'
                    invoke 'doc'

task 'doc', 'Build documentation', ->
    exec 'docco src/*.coffee', (err, stdout, stderr) ->
        util.error strerr if stderr
        console.log stdout if stdout
grrrr = (message = '') -> 
    util.error message
