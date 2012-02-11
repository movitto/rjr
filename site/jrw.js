/* Json-Rpc over Websockets
 */

// helpers to generate 'uuid'
function S4() {
  return (((1+Math.random())*0x10000)|0).toString(16).substring(1);
}
function guid() {
  return (S4()+S4()+"-"+S4()+"-"+S4()+"-"+S4()+"-"+S4()+S4()+S4());
}

// helper to get an object's class
function getObjectClass(obj) {
    if (obj && obj.constructor && obj.constructor.toString) {
        var arr = obj.constructor.toString().match(
            /function\s*(\w+)/);

        if (arr && arr.length == 2) {
            return arr[1];
        }
    }

    return undefined;
}

// encapsulates an object w/ type
//  - adaptor for the ruby 'json' library
function JRObject (type, value){
  this.to_json = function(){
     return {json_class: type, data: value };
  };
};

JRObject.is_jrobject = function(json){
  return json && json['json_class'] && json['data'];
};

JRObject.from_json = function(json){
  return json['data'];
};

// main json-rpc websocket interface
function WSNode (host, port){
  node = this;
  this.open = function(){
    this.socket = new MozWebSocket("ws://" + host + ":" + port);
    this.socket.onopen = function (){
      // XXX hack, give other handlers time to register
      setTimeout(function(){
        if(node.onopen)
          node.onopen();
      }, 250);
    };
    this.socket.onclose   = function (){
      if(node.onclose)
        node.onclose();
    };
    this.socket.onmessage = function (e){
      msg = e.data;
      msg = $.parseJSON(msg);
      if(node.onmessage)
        node.onmessage(msg);
    };
  };
  this.invoke_request = function(){
    id = guid();
    rpc_method = arguments[0];
    args = [];
    for(a = 1; a < arguments.length; a++){
      if(getObjectClass(arguments[a]) == "JRObject")
        args.push(arguments[a].to_json());
      else
        args.push(arguments[a]);
    }
    request = {jsonrpc:  '2.0',
               method: rpc_method,
               params: args,
               id: id};
    this.onmessage = function(msg){
      if(this.message_received)
        this.message_received(msg);
      if(msg['id'] == id){
        success = !msg['error'];
        if(success && this.onsuccess){
          result = msg['result'];
          if(JRObject.is_jrobject(result))
            result = JRObject.from_json(result);
          this.onsuccess(result);
        }
        else if(!success && this.onfailed)
          this.onfailed(msg['error']['code'], msg['error']['message']);
      }else{
        if(msg['method'] && this.invoke_callback){
          params = msg['params'];
          for(i=0;i<params.length;++i)
            if(JRObject.is_jrobject(params[i]))
              params[i] = JRObject.from_json(params[i]);
          this.invoke_callback(msg['method'], params);
        }
      }
    };
    this.socket.send($.toJSON(request));
  };
  this.close = function(){
    this.socket.close();
  };
};

// main json-rpc www interface
function WebNode (uri){
  node = this;
  this.invoke_request = function(){
    id = guid();
    rpc_method = arguments[0];
    args = [];
    for(a = 1; a < arguments.length; a++){
      if(getObjectClass(arguments[a]) == "JRObject")
        args.push(arguments[a].to_json());
      else
        args.push(arguments[a]);
    }
    request = {jsonrpc:  '2.0',
               method: rpc_method,
               params: args,
               id: id};

    $.ajax({type: 'POST',
            url: uri,
            data: $.toJSON(request),
            dataType: 'json',
            success: function(data){
              if(node.message_received)
                node.message_received(data);
              success = !data['error'];
              if(success && node.onsuccess){
                result = data['result'];
                if(JRObject.is_jrobject(result))
                  result = JRObject.from_json(result);
                node.onsuccess(result);
              }
              else if(!success && node.onfailed)
                node.onfailed(data['error']['code'], data['error']['message']);
            },
            error: function(jqXHR, textStatus, errorThrown){
              if(node.onfailed)
                node.onfailed(jqXHR.status, textStatus);
            }});
  };
};
