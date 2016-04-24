whilelse-graph = require '..'
assert = require('chai').assert

test 'repo defined', !->
  assert whilelse-graph.repo
