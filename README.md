## RJR - Ruby Json Rpc Library ##

Copyright (C) 2012 Mo Morsi <mo@morsi.org>

RJR is made available under the Apache License, Version 2.0

RJR is an implementation of the {http://en.wikipedia.org/wiki/JSON-RPC JSON-RPC}
Version 2.0 Specification. It allows a developer to register custom JSON-RPC
method handlers which may be invoked simultaneously over a variety of transport
mechanisms.

Currently supported transports include:
    tcp, amqp, http (post), websockets, local method calls, (udp coming soon)

### Intro ###
To install rjr simply run:
    gem install rjr

Source code is available via:
    git clone http://github.com/movitto/rjr

### Using ###

Simply require rubygems and the rjr library

    require 'rubygems'
    require 'rjr'

server.rb:

    # define a rpc method called 'hello' which takes
    # one argument and returns it in upper case
    RJR::Dispatcher.add_handler("hello") { |arg|
      arg.upcase
    }

    # listen for this method via amqp, websockets, http, and via local calls
    amqp_node  = RJR::AMQPNode.new  :node_id => 'server', :broker => 'localhost'
    ws_node    = RJR::WSNode.new    :node_id => 'server', :host   => 'localhost', :port => 8080
    www_node   = RJR::WebNode.new   :node_id => 'server', :host   => 'localhost', :port => 8888
    local_node = RJR::LocalNode.new :node_id => 'server'

    # start the server and block
    multi_node = RJR::MultiNode.new :nodes => [amqp_node, ws_node, www_node, local_node]
    multi_node.listen
    multi_node.join


amqp_client.rb:

    # invoke the method over amqp
    amqp_node = RJR::AMQPNode.new :node_id => 'client', :broker => 'localhost'
    puts amqp_node.invoke_request('server-queue', 'hello', 'world')


ws_client.js:

    // use the js client to invoke the method via a websocket
    <script type="text/javascript" src="http://ajax.googleapis.com/ajax/libs/jquery/1.7.1/jquery.min.js"></script>
    <script type="text/javascript" src="site/json.js" />
    <script type="text/javascript" src="site/jrw.js" />
    <script type="text/javascript">
    var node = new WSNode('127.0.0.1', '8080');
    node.onopen = function(){
      node.invoke_request('hello', 'rjr');
    };
    node.onsuccess = function(result){
      alert(result);
    };
    node.open();
    </script>

### Reference ###

The source repository can be found {https://github.com/movitto/rjr here}

Online API documentation and examples can be found {http://rubydoc.info/github/movitto/rjr here}

Generate documentation via

    rake yard

Also see specs for detailed usage.

### Advanced ###

RJR uses {http://rubyeventmachine.com/ eventmachine} to process server requests.
Upon being received requests are handed off to a thread pool to free up the reactor.
It is up to the developer to ensure resources accessed in the method handlers
are protected from concurrent access.

Various metadata fields are made available to json-rpc method handlers through
instance variables. These include:


<pre>* @rjr_node
* @rjr_node_id
* @rjr_node_type
* @rjr_callback
* @headers
* @client_ip
* @client_port
* @method
* @method_args
* @handler
</pre>

RJR implements a callback interface through which methods may be invoked on a client
after an initial server connection is established. Store and/or invoke @rjr_callback to make
use of this.

    RJR::Dispatcher.add_handler("register_callback") { |*args|
      $my_registry.invoke_me_later {
        # rjr callback will already be setup to send messages to the correct client
        @rjr_callback.invoke 'callback_method', 'with', 'custom', 'params'
      }
    }

RJR also permits arbitrary headers being set on JSON-RPC requests and responses. These
will be stored in the json send to/from nodes, at the same level/scope as the message
'id', 'method', and 'params' properties. Developers using RJR may set and leverage these headers
in their registered handlers to store additional metadata to extend the JSON-RPC protocol and
support any custom subsystems (an auth subsystem for example)

    RJR::Dispatcher.add_handler("login") { |*args|
      if $my_user_registry.find(:user => args.first, :pass => args.last)
        @headers['session-id'] = $my_user_registry.create_session.id
      end
    }

    RJR::Dispatcher.add_handler("do_secure_action") { |*args|
      if $my_user_registry.find(:session_id => @headers['session-id']).nil?
        raise PermissionError, "invalid session"
      end
      # ...
    }

Of course any custom headers set/used will only be of use to JSON-RPC nodes running
RJR as this is not standard JSON-RPC.


### Authors ###
Mo Morsi <mo@morsi.org>
