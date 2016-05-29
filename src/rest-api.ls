require! 'express'
require! 'url'

module.exports =
  start: (port = 3025, path = "/dy2") ->
    app = express!

    app.get "#{path}/load/:document", (req, res) ->
      document = req.params.document
      {create-repo-from-document} = require './doc-loader'
      create-repo-from-document document, (repo) ->
        raw-repo = repo.export-repo!
        res.send "#{JSON.stringify(raw-repo)}\n"

    server = app.listen port, ->
      host = server.address!.address
      port = server.address!.port
      console.log 'Listening on http://%s:%s', host, port


if process.argv[0] == 'node' && process.argv[1] == __filename
  module.exports.start!

