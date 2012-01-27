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
  return json['json_class'] && json['data'];
};

JRObject.from_json = function(json){
  return json['data'];
};

// main json-rpc interface
function JRNode (host, port){
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
      if(msg['id'] == id){
        success = msg['result'];
        if(success && this.onsuccess){
          result = msg['result'];
          if(JRObject.is_jrobject(result))
            result = JRObject.from_json(result);
          this.onsuccess(result);
        }
        else if(!success && this.onfailed)
          this.onfailed(msg['error']['code'], msg['error']['message']);
      }
    };
    this.socket.send($.toJSON(request));
  };
  this.close = function(){
    this.socket.close();
  };
};
