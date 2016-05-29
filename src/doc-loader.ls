# TODO: extract non-nodejs-specific stuff, so that it can be used with other storage mechanisms (e.g. localstorage)
# TODO: move default document commands elsewhere

require! 'fs'
prelude = require 'prelude-ls'
{find,each,map,join} = prelude
Repo = require './repo'
path = require 'path'

each-command = (document, state, cmd-cb, cont-cb) ->
  is-main-doc = ! state
  state ?= { loaded: {}, root: null }
  return if state.loaded[document]
  state.loaded[document] = true
  source-file-name = path.join(__dirname, "../documents/#{document}.dylog")
  create-if-not-exists source-file-name, document, ->
    lines = fs.read-file-sync source-file-name .to-string! .split(/\r?\n/)
    #console.log "LINES #{document}", lines.length
    #source = readline.create-interface input: fs.create-read-stream source-file-name
    #source.on 'line', (line) ->
    for line in lines
      continue if line == ''
      #console.log 'LINE', line
      wire-cmd = JSON.parse(line)
      if wire-cmd[0] == 'dep'
        each-command wire-cmd[1].name, state, cmd-cb, ->
      else if is-main-doc && wire-cmd[0] == 'comp' && ! state.root
        state.root = wire-cmd[1].ni
        cmd-cb(['root',{ ni: state.root }])
        cmd-cb(wire-cmd)
      else
        cmd-cb(wire-cmd)
    #source.on 'close', ->
    cont-cb! if cont-cb

commands-for-document = (document, cont-cb) ->
  commands = []
  process-command = (wire-cmd) ->
    if wire-cmd[0] == 'undo'
      n = wire-cmd[1].val || 1
      commands.splice(commands.length - n, n)
    else
      commands.push wire-cmd
  each-command document, null, process-command, ->
    cont-cb(commands)

create-repo-from-document = (document, cont-cb) ->
  repo = new Repo!

  commands-for-document document, (commands) ->
    for wire-cmd in commands
      #console.log 'PROCESS', JSON.stringify wire-cmd
      repo.process-wire-cmd wire-cmd
    cont-cb repo

create-if-not-exists = (path, document, cont-cb) ->
  if ! file-exists path
    cmds = [
      ["dep",{"name":"lib"}]
      ["dep",{"name":"testing"}]
      ["dep",{"name":"web"}]
      ["dep",{"name":"react"}]
      ["comp",{"ri":"ac#{random-string!}","sni":"9","rti":"8","ni":"ac#{random-string!}","nti":"7","name":"#{document}-workspace"}]
    ]
    data = cmds |> map ((c) -> "#{JSON.stringify(c)}\n") |> join ''
    fs.writeFile path, data, (err) ->
      throw err if err
      #console.log "WRITTEN #{path}"
      cont-cb!
  else
    cont-cb!

file-exists = (path) ->
  try
    fs.access-sync(path)
    true
  catch e # FIXME: don't catch all
    false

random-string = (length = 10) -> # length 10 fits on <64 bits
  chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  n = chars.length
  s = ''
  for i from 1 to length
    s += chars[Math.floor(Math.random! * n)]
  s

module.exports = {
  each-command
  commands-for-document
  create-repo-from-document
}
