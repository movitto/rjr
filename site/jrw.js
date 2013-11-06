/* Json-Rpc over HTTP and Websockets
 *
 *  Copyright (C) 2013 Mohammed Morsi <mo@morsi.org>
 *  Licensed under the Apache License, Version 2.0
 */

var RJR = { REVISION: '1' };

// Generate a new ascii string of length 4
RJR.S4 = function() {
  return (((1+Math.random())*0x10000)|0).toString(16).substring(1);
};

// Generate a new uuid
RJR.guid = function() {
  return (RJR.S4()+RJR.S4()+"-"+RJR.S4()+"-"+RJR.S4()+"-"+RJR.S4()+"-"+RJR.S4()+RJR.S4()+RJR.S4());
};

// Encapsulates a json-rpc message
RJR.JRMessage = function(){
  this.id = null;
  this.rpc_method = null;
  this.args = null;

  this.data = null;
  this.json = null;

  this.error = null;
  this.result = null;

  this.onresponse = null;
  this.success   = null;
};

RJR.JRMessage.prototype = {
  to_json : function(){
    this.json = $.toJSON(this.data);
    return this.json;
  },

  handle_response : function(res){
    res.success = (res.error == undefined);
    if(this.onresponse)
      this.onresponse(res);
  }
};

// Create new request message to send
RJR.JRMessage.new_request = function(rpc_method, args){
  var msg = new RJR.JRMessage();
  msg.id = RJR.guid();
  msg.rpc_method = rpc_method;
  msg.args = args;
  msg.data = {jsonrpc:  '2.0',
              method: msg.rpc_method,
              params: msg.args,
              id: msg.id};
  return msg;
};

// Internal helper to generate request from common args.
//
// rpc method, parameter list, and optional response callback
// will be extracted from the 'args' param in that order.
//
// node_id and headers will be set on request message before it
// is returned
RJR.JRMessage.pretty_request = function(args, node_id, headers){
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
  var req = RJR.JRMessage.new_request(rpc_method, params);
  if(node_id) req.data['node_id'] = node_id;
  for(var header in headers)
    req.data[header] = headers[header];

  // register callback if last argument is a function
  if(cb) req.onresponse = cb;

  return req;
};

// Parse message received in json string
RJR.JRMessage.from_msg = function(dat){
  var msg = new RJR.JRMessage();
  msg.json = dat;
  msg.data = $.evalJSON(dat);

  msg.id = msg.data['id'];
  msg.rpc_method = msg.data['method'];
  if(msg.data['params']){
    msg.params = msg.data['params'];
    for(p=0;p<msg.params.length;++p){
      if(RJR.JRObject.is_jrobject(msg.params[p]))
        msg.params[p] = RJR.JRObject.from_json(msg.params[p]);
      else if(RJR.JRObject.is_jrobject_array(msg.params[p]))
        msg.params[p] = RJR.JRObject.from_json_array(msg.params[p]);
    }
  }
  msg.error  = msg.data['error'];
  msg.result = msg.data['result'];
  if(msg.result && RJR.JRObject.is_jrobject(msg.result))
    msg.result = RJR.JRObject.from_json(msg.result);
  else if(RJR.JRObject.is_jrobject_array(msg.result))
    msg.result = RJR.JRObject.from_json_array(msg.result);
  return msg;
}

// Encapsulates an object w/ type
//  - adaptor for the ruby 'json' library
RJR.JRObject = function (type, value, ignore_properties){
  this.type  = type;
  this.value = value;
  this.ignore_properties = (typeof(ignore_properties) != 'undefined') ?
                            ignore_properties : ["toJSON", "json_class"];
};

RJR.JRObject.prototype = {
  toJSON : function(){
     var data = {};
     for(p in this.value)
       if($.inArray(p, this.ignore_properties) == -1)
         data[p] = this.value[p];
     return {json_class: this.type, data: data };
  }
};

// Return boolean indicating if json contains encapsulated JRObject
RJR.JRObject.is_jrobject = function(json){
  return json && json['json_class'] && json['data'];
};

// Return boolean indicating if json contains array of encapsulated JRObjects
RJR.JRObject.is_jrobject_array = function(json){
  return json && typeof(json) == "object" && json.length > 0 && RJR.JRObject.is_jrobject(json[0]);
};

// Convert json to JRObject
RJR.JRObject.from_json = function(json){
  var obj = json['data'];
  obj.json_class = json['json_class'];
  for(var p in obj){
    if(RJR.JRObject.is_jrobject(obj[p]))
      obj[p] = RJR.JRObject.from_json(obj[p]);
    else if(RJR.JRObject.is_jrobject_array(obj[p])){
      obj[p] = RJR.JRObject.from_json_array(obj[p]);
   }
  }
  return obj;
};

// Convert json to array of JRObjects
RJR.JRObject.from_json_array = function(json){
  var objs = [];
  for(var i in json)
    if(RJR.JRObject.is_jrobject(json[i]))
      objs[i] = RJR.JRObject.from_json(json[i]);
  return objs;
};

// Main json-rpc client websocket interface
RJR.WsNode = function(host, port){
  this.host     = host;
  this.port     = port;
  this.opening  = false;
  this.opened   = false;
  this.node_id  = null;
  this.headers  = {};
  this.messages = {};
}

RJR.WsNode.prototype = {
  // Open socket connection
  open : function(){
    var node = this;
    if(this.opening) return;
    this.opening = true;
    this.socket = new WebSocket("ws://" + this.host + ":" + this.port);
    this.socket.onclose   = function(){ node._socket_close(); };
    this.socket.onmessage = function(evnt){ node._socket_msg(evnt);  };
    this.socket.onerror   = function(err){ node._socket_err(err);  };
    this.socket.onopen    = function(){ node._socket_open(); };

  },

  _socket_close : function(){
    if(this.onclose) this.onclose();
  },

  _socket_msg : function(evnt){
    var msg = RJR.JRMessage.from_msg(evnt.data);

    // match response w/ outstanding request
    if(msg.id){
      var req = this.messages[msg.id];
      delete this.messages[msg.id];
      req.handle_response(msg)

      // if err msg, run this.onerror
      if(msg.error)
        if(this.onerror)
          this.onerror(msg)
    }

    // relying on clients to handle notifications via message_received
    // TODO add notification (and request?) handler support here
    // clients may user this to register additional handlers to be invoked
    // upon request responses
    if(this.message_received)
      this.message_received(msg);
  },

  _socket_err : function(e){
    if(this.onerror)
      this.onerror(e);
  },

  _socket_open : function(){
    this.opened = true;
    this.opening = false;

    // send queued messages
    for(var m in this.messages)
      this.socket.send(this.messages[m].to_json());

    // invoke client callback
    if(this.onopen)
      this.onopen();
  },

  // Close socket connection
  close : function(){
    this.socket.close();
  },

  // Invoke request on socket, may be invoked before or after socket is opened.
  //
  // Pass in the rpc method, arguments to invoke method with, and optional callback
  // to be invoked upon received response.
  invoke : function(){
    var req = RJR.JRMessage.pretty_request(arguments, this.node_id, this.headers);

    // store requests for later retrieval
    this.messages[req.id] = req;

    if(this.opened)
      this.socket.send(req.to_json());

    return req;
  }
};

// Main json-rpc http interface
RJR.HttpNode = function(uri){
  this.uri      = uri;
  this.node_id  = null;
  this.headers  = {};
};

RJR.HttpNode.prototype = {
  // Invoke request via http
  //
  // Pass in the rpc method, arguments to invoke method with, and optional callback
  // to be invoked upon received response.
  invoke : function(){
    var req = RJR.JRMessage.pretty_request(arguments, this.node_id, this.headers);

    var node      = this;
    $.ajax({type: 'POST',
            url: this.uri,
            data: req.to_json(),
            dataType: 'text', // using text so we can parse json ourselves
            success: function(data) { node._http_success(data, req); },
            error:   function(hr, st, et) { node._http_err(hr, st, et, req); }});

    return req;
  },

  _http_success : function(data, req){
    var msg = RJR.JRMessage.from_msg(data);
    // clients may register additional callbacks
    // to handle web node responses
    if(this.message_received)
      this.message_received(msg);

    req.handle_response(msg)

    // if err msg, run this.onerror
    if(msg.error)
      if(this.onerror)
        this.onerror(msg);
  },

  _http_err : function(jqXHR, textStatus, errorThrown, req){
    var err = { 'error' : {'code' : jqXHR.status,
                           'message' : textStatus,
                           'class' : errorThrown } };
    if(this.onerror)
      this.onerror(err);

    req.handle_response(err)
  }
};
