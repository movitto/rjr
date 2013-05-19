/* Json-Rpc over HTTP and Websockets
 *
 *  Copyright (C) 2013 Mohammed Morsi <mo@morsi.org>
 *  Licensed under the Apache License, Version 2.0
 */

///////////////////////////////////////////////////////
// Helpers to generate a uuid
function S4() {
  return (((1+Math.random())*0x10000)|0).toString(16).substring(1);
}
function guid() {
  return (S4()+S4()+"-"+S4()+"-"+S4()+"-"+S4()+"-"+S4()+S4()+S4());
}

///////////////////////////////////////////////////////
// JRMessage

// Encapsulates a json-rpc message
function JRMessage(){
  this.id = null;
  this.rpc_method = null;
  this.args = null;

  this.data = null;
  this.json = null;

  this.error = null;
  this.result = null;

  this.onresponse = null;
  this.success   = null;

  this.to_json = function(){
    this.json = $.toJSON(this.data);
    return this.json;
  }

  this.handle_response = function(res){
    res.success = (res.error == undefined);
    if(this.onresponse)
      this.onresponse(res);
  }
}

// Create new request message to send
JRMessage.new_request = function(rpc_method, args){
  var msg = new JRMessage();
  msg.id = guid();
  msg.rpc_method = rpc_method;
  msg.args = args;
  msg.data = {jsonrpc:  '2.0',
              method: msg.rpc_method,
              params: msg.args,
              id: msg.id};
  return msg;
}

// Internal helper to generate request from common args.
//
// rpc method, parameter list, and optional response callback
// will be extracted from the 'args' param in that order.
//
// node_id and headers will be set on request message before it
// is returned
JRMessage.pretty_request = function(args, node_id, headers){
  // create request message
  var rpc_method = args[0];
  var params = [];
  var cb = null;
  for(a = 1; a < args.length; a++){
      if(a == args.length - 1 && typeof args[a] === 'function')
        cb = args[a];
      else
        params.push(args[a]);
  }
  var req = JRMessage.new_request(rpc_method, params);
  if(node_id) req.data['node_id'] = node_id;
  for(var header in headers)
    req.data[header] = headers[header];

  // register callback if last argument is a function
  if(cb) req.onresponse = cb;

  return req;
}

// Parse message received in json string
JRMessage.from_msg = function(dat){
  var msg = new JRMessage();
  msg.json = dat;
  msg.data = $.evalJSON(dat);

  msg.id     = msg.data['id'];
  msg.rpc_method = msg.data['method'];
  if(msg.data['params']){
    msg.params = msg.data['params'];
    for(p=0;p<msg.params.length;++p){
      if(JRObject.is_jrobject(msg.params[p]))
        msg.params[p] = JRObject.from_json(msg.params[p]);
      else if(JRObject.is_jrobject_array(msg.params[p]))
        msg.params[p] = JRObject.from_json_array(msg.params[p]);
    }
  }
  msg.error  = msg.data['error'];
  msg.result = msg.data['result'];
  if(msg.result && JRObject.is_jrobject(msg.result))
    msg.result = JRObject.from_json(msg.result);
  else if(JRObject.is_jrobject_array(msg.result))
    msg.result = JRObject.from_json_array(msg.result);
  return msg;
}

///////////////////////////////////////////////////////
// JRObject

// Encapsulates an object w/ type
//  - adaptor for the ruby 'json' library
function JRObject (type, value, ignore_properties){
  this.type  = type;
  this.value = value;
  this.ignore_properties = (typeof(ignore_properties) != 'undefined') ?
                            ignore_properties : ["toJSON"];
  this.toJSON = function(){
     var data = {};
     for(p in this.value)
       if($.inArray(p, this.ignore_properties) == -1)
         data[p] = value[p];
     return {json_class: this.type, data: data };
  };
};

// Return boolean indicating if json contains encapsulated JRObject
JRObject.is_jrobject = function(json){
  return json && json['json_class'] && json['data'];
};

// Return boolean indicating if json contains array of encapsulated JRObjects
JRObject.is_jrobject_array = function(json){
  return json && typeof(json) == "object" && json.length > 0 && JRObject.is_jrobject(json[0]);
};

// Convert json to JRObject
JRObject.from_json = function(json){
  var obj = json['data'];
  obj.json_class = json['json_class'];
  for(var p in obj){
    if(JRObject.is_jrobject(obj[p]))
      obj[p] = JRObject.from_json(obj[p]);
    else if(JRObject.is_jrobject_array(obj[p])){
      obj[p] = JRObject.from_json_array(obj[p]);
   }
  }
  return obj;
};

// Convert json to array of JRObjects
JRObject.from_json_array = function(json){
  var objs = [];
  for(var i in json)
    if(JRObject.is_jrobject(json[i]))
      objs[i] = JRObject.from_json(json[i]);
  return objs;
};

///////////////////////////////////////////////////////
// WSNode

// Main json-rpc client websocket interface
function WSNode (host, port){
  var node      = this;
  this.opened   = false;
  this.node_id  = null;
  this.headers  = {};
  this.messages = {};

  // Open socket connection
  this.open = function(){
    node.socket = new WebSocket("ws://" + host + ":" + port);

    node.socket.onclose   = function (){
      if(node.onclose)
        node.onclose();
    };

    node.socket.onmessage = function (evnt){
      var msg = JRMessage.from_msg(evnt.data);

      // match response w/ outstanding request
      if(msg.id){
        var req = node.messages[msg.id];
        delete node.messages[msg.id];
        req.handle_response(msg)

        // if err msg, run node.onerror
        if(msg.error)
          if(node.onerror)
            node.onerror(msg)

      }else{
        // relying on clients to handle notifications via message_received
        // TODO add notification (and request?) handler support here
        //node.invoke_method(msg.rpc_method, msg.params)
        if(node.message_received)
          node.message_received(msg);

      }
    };

    node.socket.onerror = function(e){
      if(node.onerror)
        node.onerror(e);
    }

    node.socket.onopen = function (){
      // send queued messages
      for(var m in node.messages)
        node.socket.send(node.messages[m].to_json());

      node.opened = true;

      // invoke client callback
      if(node.onopen)
        node.onopen();
    };
  };

  // Close socket connection
  this.close = function(){
    this.socket.close();
  };

  // Invoke request on socket, may be invoked before or after socket is opened.
  //
  // Pass in the rpc method, arguments to invoke method with, and optional callback
  // to be invoked upon received response.
  this.invoke = function(){
    var req = JRMessage.pretty_request(arguments, this.node_id, this.headers);

    // store requests for later retrieval
    this.messages[req.id] = req;

    if(node.opened)
      this.socket.send(req.to_json());

    return req;
  };
};

///////////////////////////////////////////////////////
// WebNode

// Main json-rpc www interface
function WebNode (uri){
  var node      = this;
  this.node_id  = null;
  this.headers  = {};

  // Invoke request via http
  //
  // Pass in the rpc method, arguments to invoke method with, and optional callback
  // to be invoked upon received response.
  this.invoke = function(){
    var req = JRMessage.pretty_request(arguments, this.node_id, this.headers);

    $.ajax({type: 'POST',
            url: uri,
            data: req.to_json(),
            dataType: 'text', // using text so we can parse json ourselves

            success: function(data){
              var msg = JRMessage.from_msg(data);
              // js web client doesn't support notifications
              //if(node.message_received)
                //node.message_received(msg);

              req.handle_response(msg)

              // if err msg, run node.onerror
              if(msg.error)
                if(node.onerror)
                  node.onerror(msg);
            },

            error: function(jqXHR, textStatus, errorThrown){
              var err = { 'error' : {'code' : jqXHR.status,
                                     'message' : textStatus,
                                     'class' : errorThrown } };
              if(node.onerror)
                node.onerror(err);

              req.handle_response(err)
            }});

    return req;
  };
};
