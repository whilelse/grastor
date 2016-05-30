Grastor
=======

Graph storage mechanism for [Whilelse](http://whilelse.com/).

The storage graph is composed of Nodes and Refs which are linked to

The graph consits of Nodes which are connected by Refs.

A Node consists of:

* *ID* - unique identifier, by which other nodes can reference it
* *name* - a string that can be shown on the UI, acts as a special attribute
* *type* - points to a `node_type` node
* *attrs* - set of Attributes
* *refs* - array of pointers to Refs, through which they point to other nodes
* *inrefs* - inbound refs, array of pointers to Refs which point to this node

An Attribute consists of:

* *type*, which points to an `attr_type` node
* *value*, which can be a string, number or boolean

A Ref consists of:

* *type*, which points to a `ref_type` node
* *source* node pointer
* *target* node pointer
* *dependent* flag, that determines whether the target is treated as a component of the source node or the source node simply links to the target

The primary storage mechanism is a sequence of commands executed on the graph model.
The graph is generated from this sequence of commands.

![Storage Graph Diagram](http://whilelse.com/diagrams/storage-web.png)

## Setup

Watch and compile livescript:

    ./bin/watch

Run REST server:

    node lib/rest-api.js
