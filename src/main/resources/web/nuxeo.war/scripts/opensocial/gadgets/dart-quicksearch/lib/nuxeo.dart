library nuxeo;

import 'dart:html';
import 'dart:json';
import 'package:js/js.dart' as js;

abstract class AutomationClient {
  String url;
  OperationRegistry _registry;
  
  AutomationClient(this.url);
  
  Future<OperationRegistry> getRegistry();
  
  get baseUrl => url;
}

class GadgetAutomationClient extends AutomationClient {
  
  GadgetAutomationClient() : super(js.scoped(() => "${js.context.NXGadgetContext.clientSideBaseUrl}site/automation"));
  
  get baseUrl => url;
  
  Future<Session> getSession() => getRegistry().transform((_) => new Session(this));
  
  Future<OperationRegistry> getRegistry() {
    var completer = new Completer<OperationRegistry>();
    
    if (_registry == null) { 
      var request = new HttpRequest();
      request.open('GET', url, true);
      request.setRequestHeader("Accept", CTYPE_AUTOMATION);
      request.on.readyStateChange.add((e) {
        if (request.readyState == HttpRequest.DONE &&
            (request.status == 200 || request.status == 0)) {
          var json = JSON.parse(request.response);
          _registry = new OperationRegistry.fromJSON(json);
          completer.complete(_registry);
        }
      });
      request.send();
      
    } else {
      completer.complete(_registry);
    }
    return completer.future;
  }
}

class Session {
  AutomationClient client;
  
  Session(this.client);
  
  newRequest(String id, [Map<String, Object> ctx]) {
    var op = getOperation(id);
    if (op == null) {
      throw new IllegalArgumentException("No such operation: $id");
    }
    if (!?ctx) ctx = {};
    return new OperationRequest(this, op, ctx);
  }
  
  OperationDocumentation getOperation(String id) => client._registry.getOperation(id);
 
  Future execute(OperationRequest request) {
    var completer = new Completer<String>();
    
    js.scoped( () {
      var nxParams = js.map({
        'operationId': request.op.id,
        'operationParams': js.map(request.params),
        'operationContext': js.map(request.ctx),
        'operationDocumentProperties': request.documentProperties,
        'entityType':'documents',
        'usePagination': request.usePagination,
        'displayMethod': new js.Callback.once(request.displayMethod),
        'noEntryLabel': request.noEntryLabel,
        'displayColumns': js.array(request.displayColumns.map((d) => js.map(d))),
        //'operationCallback': new js.Callback.once((response, nxParams) {
        //  completer.complete(response);
        //})
      });
      
      js.context.doAutomationRequest(nxParams);
      
      return completer.future;
    });
  }
}

displayDocumentList(entries, nxParams) {
  js.scoped( () {
    js.context.displayDocumentList(entries, nxParams);
  });
}

typedef DisplayMethod(entries, nxParams);

class OperationRequest {
  var params = new Map<String, String>();
  Map<String, Object> ctx = {};
  
  Session session;
  OperationDocumentation op;
  
  // Used in doAutomationRequest
  
  /// schema that must be fetched from resulting documents
  String documentProperties;
  
  /// manage pagination or not
  bool usePagination;
  
  /// js method used to display the result
  DisplayMethod displayMethod;
  
  List<Map<String, String>> displayColumns;
  
  String noEntryLabel;
  
  OperationRequest(this.session, this.op, [this.ctx]);
  
  OperationParam getParam(String key) {
    var res = op.params.filter((p) => key == p.name);
    if (res.isEmpty) {
      return null;
    }
    return res.iterator().next();
  }
  
  get paramNames => op.params.map( (p) => p.name );
  
  operator []=(String key, value) {
    var param = getParam(key);
    if (param == null) {
      throw new IllegalArgumentException("No such parameter '$key' for operation ${op.id}.\n\tAvailable params: ${paramNames.join(",")}");
    }
    if (value == null) {
      params.remove(key);
      return this;
    }
    if (value is Date) {
      params[key] = value.toString(); // TODO - format date
    } else {
      params[key] = value.toString();
    }
  }
  
  Object execute() => session.execute(this);
  
  toJSON() => "";
  
  get url => "${session.client.baseUrl}${op.url}";
}

class OperationParam {

  String name;

  String type; // the data type

  String widget; // the widget type

  List<String> values; // the default values

  bool isRequired;

  num order;
  
  OperationParam();
  
  factory OperationParam.fromJSON(Map<String, Object> json)
   => new OperationParam()
    ..name = json["name"]
   ..type = json["type"]
   ..isRequired = json["required"]
   ..widget = json["widget"]
   ..order = json["order"];
  
  toString() => "$name [$type] ${isRequired ? "required" : "optional"}";
}

class OperationDocumentation {
  String id;
  String label;
  String category;
  String requires;
  String description;
  String url;
  List<OperationParam> params;
  
  OperationDocumentation();
  
  factory OperationDocumentation.fromJSON(Map<String, Object> json)
    => new OperationDocumentation()
    ..id = json["id"]
    ..label = json["label"]
    ..category = json["category"]
    ..requires = json["requires"]
    ..url = json["url"]
    ..params = (json["params"] as List).map((p) => new OperationParam.fromJSON(p));
}

class OperationRegistry {
  Map<String, String> paths;
  Map<String, OperationDocumentation> ops;
  Map<String, OperationDocumentation> chains;
  
  OperationRegistry(this.paths, this.ops, this.chains);
  
  factory OperationRegistry.fromJSON(Map<String, Object> json) {

    var paths = json["paths"];
    
    var ops = {};
    (json["operations"] as List).forEach((json) {
      var op = new OperationDocumentation.fromJSON(json);
      ops[op.id] = op;
    });
    
    var chains = {};
    
    return new OperationRegistry(paths, ops, chains);
  }
  
  getPath(String key) => paths[key];
  
  getOperation(String key)=> ops.containsKey(key) ? ops[key] : chains[key];
}


const CTYPE_AUTOMATION = "application/json+nxautomation";
const CTYPE_ENTITY = "application/json+nxentity";
const CTYPE_REQUEST_NOCHARSET = "application/json+nxrequest";