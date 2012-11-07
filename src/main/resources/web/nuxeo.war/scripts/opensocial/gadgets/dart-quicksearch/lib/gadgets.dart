library gadgets;

import 'package:js/js.dart' as js;

class Prefs {
  var _jsPrefs;
  
  Prefs() {
    js.scoped(() {
      _jsPrefs = js.retain(new js.Proxy(js.context.gadgets.Prefs));
    });
  }
  
  operator []=(String key, String value) => js.scoped(() => _jsPrefs["set"](key, value));
  String getMsg(String label) => js.scoped(() => _jsPrefs.getMsg(label));
  String getString(String name) => js.scoped(() => _jsPrefs.getString(name));
}

get window => new _Window();

class _Window { 
  adjustHeight() => js.scoped(() => js.context.gadgets.window.adjustHeight());
}

var util = new _Util();

class _Util {
  registerOnLoadHandler(cb) {
    js.scoped(() {
      js.context.gadgets.util.registerOnLoadHandler(new js.Callback.once(cb));
    });
  }
}

gel(q) => js.scoped(() => js.context._gel(q));
