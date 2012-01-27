/* Json-Rpc over Websockets
 */

// helpers to generate 'uuid'
function S4() {
  return (((1+Math.random())*0x10000)|0).toString(16).substring(1);
}
function guid() {
  return (S4()+S4()+"-"+S4()+"-"+S4()+"-"+S4()+"-"+S4()+S4()+S4());
}

function JRNode (host, port){
  node = this;
  this.open = function(){
    this.socket = new MozWebSocket("ws://" + host + ":" + port);
    $(this.socket).bind('open', function(){
      if(node.onopen)
        node.onopen();
    });
    $(this.socket).bind('close', function(){
      if(node.onclose)
        node.onclose();
    });
    $(this.socket).bind('message', function(e){
      msg = e.originalEvent.data;
      msg = $.parseJSON(msg);
      console.log(msg);
      if(node.onmessage)
        node.onmessage(msg);
    });
  };
  this.invoke_request = function(){
    id = guid();
    rpc_method = arguments[0];
    args = [];
    for(a = 1; a < arguments.length; a++)
      args.append(arguments[a]);
    request = {jsonrpc:  '2.0',
               method: rpc_method,
               params: args,
               id: id};
    this.onmessage = function(msg){
      if(msg['id'] == id){
        success = msg['result'];
        if(success && this.onsuccess)
          this.onsuccess(msg['result']);
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
