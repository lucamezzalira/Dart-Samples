import 'dart:html';
import 'dart:async';

List<String> images = [["1", "images/1.JPG", "custom text 1"],["2", "images/2.JPG", "custom text 2"],["3", "images/3.JPG", "custom text 3"], ["4", "images/4.JPG", "custom text 4"], ["5", "images/5.JPG", "custom text 5"], ["6", "images/6.JPG", "custom text 6"], ["7", "images/7.JPG", "custom text 7"],["8", "images/8.JPG", "custom text 8"],["9", "images/9.JPG", "custom text 9"]];

var cont;
var bg;
var zoomImg;

void main() {
  // resize zoom image su schermi + piccoli
}

void fadeIn(event){
  var id = "#"+event.target.id;
  var img = queryAll(id);
  img.classes.remove("faded");
  img.classes.add("fade-in");
  
}

void onOver(event){
 
  var idZoom = event.target.id[4];
  var zoom = query("#zoom_"+idZoom);
  zoom.classes.remove("fade-out");
  zoom.classes.add("fade-in");
  
}

void onOut(event){
  
  var idZoom = event.target.id[4];
  var zoom = query("#zoom_"+idZoom);
  zoom.classes.remove("fade-in");
  zoom.classes.add("fade-out");
  
}

void onClick(event){
  
  zoomImg = new ImageElement(src: 'images/${event.target.id[4]}.JPG');
  zoomImg.onLoad.listen(showBigImg);
  bg = new DivElement();
  bg.classes.add("black_overlay");
  cont = new DivElement();
  cont.children.add(zoomImg);
  cont.classes.add("bigImage");
  
  cont.onClick.listen(closePopUp);
  document.body.children.add(bg);
  document.body.children.add(cont);
  
}

void showBigImg(event){
  
  bg.style.opacity = ".7";
  bg.style.transition = "1s";
  cont.style.opacity = "1";
  cont.style.transition = "1s";

}

void closePopUp(event){
  cont.style.opacity = "0";
  cont.style.transition = "1s";
  bg.style.opacity = "0";
  bg.style.transition = "1s";
  new Timer(new Duration(seconds:1), () => removeZoomObjs());
}

void removeZoomObjs(){
  
  cont.remove();
  bg.remove();
  
}

List<String> get results {
  
  return images;
  
}
