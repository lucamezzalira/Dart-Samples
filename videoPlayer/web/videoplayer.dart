import 'dart:html';

var player;
var playBtn;
var restartBtn;
var currTimeDisplay;
var volumeSlider;
var bool isWorking;

void main() {
  init();
}

void init(){
  
  volumeSlider = query("#volume");
  currTimeDisplay = query("#currTime");
  player = query("#video");
  playBtn = query("#playBtn");
  restartBtn = query("#resumeBtn");
  
  manageListeners();
  
  player.src = "video/test.mp4";
  
}

void refreshData(event){
  
  currTimeDisplay.text = returnDisplayTime(player.currentTime) + "/" + returnDisplayTime(player.duration);
  
}

void checkLoading(event){
  //after video si loaded I play it
  player.play();
  isWorking = true;
  playBtn.text = "Pause";
  
}

void playVideo(MouseEvent event){
  //managing if I've to play or pause the video
  if(isWorking){
  
    isWorking = false;
    player.pause();
    playBtn.text = "Play";
    
  } else {
    
    isWorking = true;
    player.play();
    playBtn.text = "Pause";
  
  }
  
}

void setVolume(event){
  //setting volume video value (from 0 to 1)
  player.volume = int.parse(volumeSlider.value)/100;
 
}

void restartVideo(event){
  
  player.load();
  player.play();
  
}

void manageListeners(){

  //player listeners
  player.onLoadStart.listen(checkLoading);
  player.onEnded.listen(restartVideo);
  player.onTimeUpdate.listen(refreshData);
  
  // buttons listeners
  volumeSlider.onChange.listen(setVolume);
  restartBtn.onClick.listen(restartVideo);
  playBtn.onClick.listen(playVideo);
  
}


//utils method to return the right time format
String returnDisplayTime(double value){
  
  var totSec = int.parse(value.toStringAsFixed(0));
  var min = int.parse((totSec/60).toStringAsFixed(0));
  var sec = int.parse((totSec - min*60).toStringAsFixed(0));
  var writeSec = sec.toString();
  
  if(sec < 10)
    writeSec = "0" + sec.toString();
  
  return min.toString() + ":" + writeSec;
}