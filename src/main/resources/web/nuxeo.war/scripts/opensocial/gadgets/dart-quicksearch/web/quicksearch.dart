library quicksearch;

import 'dart:html';
import 'package:quicksearch/gadgets.dart' as gadgets;
import 'package:quicksearch/nuxeo.dart' as nuxeo;

var prefs = new gadgets.Prefs();

var client = new nuxeo.GadgetAutomationClient();

doSearch() {
  var txt = (query("#searchPattern") as InputElement).value;
  runSearch(txt);
}

runSearch(txt) {
  print("Running search for $txt");
  client.getSession().then((session) {
    var op = session.newRequest("Document.PageProvider");
    op["pageSize"] = 10;
    op["documentLinkBuilder"] = prefs.getString("documentLinkBuilder");
    op.documentProperties = "common,dublincore"; // schema that must be fetched from resulting documents
    op.usePagination = true; // manage pagination or not
    op.displayMethod = nuxeo.displayDocumentList; // js method used to display the result
    op.noEntryLabel = prefs.getMsg('label.gadget.no.document');
    
    var queryType = prefs.getString("queryType");
    var displayMode = prefs.getString("displayMode");
    if ('NXQL' == queryType) {
      op["query"] = txt;
    } else {
      op["query"] = "SELECT * FROM Document WHERE ecm:fulltext LIKE ? AND ecm:mixinType != 'HiddenInNavigation' AND ecm:isCheckedInVersion = 0 AND ecm:currentLifeCycleState != 'deleted'";
      op["queryParams"] = txt;
    }
    if ('COMPACT' == displayMode) {
      op.displayColumns = [
        { "type":'builtin', "field":'icon'},
        { "type": 'builtin', "field": 'titleWithLink', "label": prefs.getMsg('label.dublincore.title')}
      ];
    } else {
      op.displayColumns = [
        {"type": 'builtin', "field": 'icon'},
        {"type": 'builtin', "field": 'titleWithLink', "label": prefs.getMsg('label.dublincore.title')},
        {"type": 'date', "field": 'dc:modified', "label": prefs.getMsg('label.dublincore.modified')},
        {"type": 'text', "field": 'dc:creator', "label": prefs.getMsg('label.dublincore.creator')}
      ];
    }
    op.execute();
  });
}

doSaveSearch() {
  var txt = (query('#searchPattern') as InputElement).value;
  prefs['savedQuery'] = txt;
  query("#searchBox").style.display = 'none';
  query("#titleBox").style.display = 'block';
  query("#queryText").innerHTML = txt;
  runSearch(txt);
}

loadSearch() {
  var txt = prefs.getString('savedQuery');
  if (txt != null && !txt.isEmpty) {
    runSearch(txt);
    query("#queryText").innerHTML = txt;
    query("#titleBox").style.display = 'block';
  } else {
    query("#searchBox").style.display = 'block';
  }
}

doEditSearch() {
  query("#searchBox").style.display = 'block';
  query("#titleBox").style.display = 'none';
}


void main() {
  
  // auto-adjust gadget height
  //gadgets.util.registerOnLoadHandler(() {
    print("OnLoadHandler");
    query("#nxDocumentListData").innerHTML = '<p>${prefs.getMsg('label.gadget.quicksearch.description')}</p>';
    query("#nxDocumentList").style.display = 'block';
    query("#pageNavigationControls").style.display = 'none';
  
    loadSearch();
    gadgets.window.adjustHeight();
  //});

  query('#doSearch').on.click.add((_) => doSearch());
  query('#doEditSearch').on.click.add((_) => doEditSearch());
  query('#doSaveSearch').on.click.add((_) => doSaveSearch());
    

  query('#searchPattern').on.keyDown.add( (KeyboardEvent event) {
    if (event.keyCode == 13) {
      doSearch();
    }
  });
}