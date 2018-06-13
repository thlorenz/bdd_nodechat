## BDD NodeChat

  This is a re-implementation of the [node sample chat room application](http://github.com/ry/node_chat/tree/master).
  The client side was virtually left untouched, but the chat server was entirely rewritten using [CoffeeScript](http://jashkenas.github.com/coffee-script/)
  in a [BDD](http://en.wikipedia.org/wiki/Behavior_Driven_Development) manner using [Jasmine](https://jasmine.github.io/).
  The router, <pre>fu.js</pre> used by the chat server was replaced with the [node-router](https://github.com/creationix/node-router).
## Why?
 I just wanted to see how easy (or not) it is to write JavaScript/CoffeeScript server side apps in a behavior driven way.
 I was positively surprised. 

## To run:

### Compile using CoffeeScript
  If not installed: <pre>npm install -g coffee-script</pre>
  Compile server and bootstrapper: <pre>coffee -c *.coffee</pre>
### Start 'em up:
   <pre>node bootstrapper</pre>
