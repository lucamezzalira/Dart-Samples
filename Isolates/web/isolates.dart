import 'dart:html';
import 'dart:isolate';
import 'dart:core';

var image, myH1;
var start, end;
var endMain, endMono, startMono;
const FINAL_AMOUNT = 100000000;
var counterIsolate;

void main() {
  
  port.receive((data, SendPort replyTo){
    
    counterIsolate++;
    end = new DateTime.now();
    
    if(counterIsolate == 2){
      var finalTime = end.difference(start).toString();
      myH1.appendHtml("isolate total time: <b>$finalTime</b><br/>");
      // if you want to close isolates you have to use the line below
      //  port.close();
    
    }
     
    
  });
  
  myH1 = query("#output");
  
  query("#monoBtn").onClick.listen(launchMono);
  query("#isolateBtn").onClick.listen(launchIsolate);
  
}

printData(){
  
  print("init speech");
  
}

void launchIsolate(event){
  counterIsolate = 0;
  start = new DateTime.now();
  var isolate = spawnFunction(bigForCycle);
  isolate.send("data", port.toSendPort());
  
  var isolate2 = spawnFunction(bigForCycle);
  isolate2.send("data", port.toSendPort());
}

void launchMono(event){

  monoThreadIteration();
}

void monoThreadIteration(){
  var count = 0;
  startMono = new DateTime.now();
  for(var i = 0; i < FINAL_AMOUNT; i++){
    
    count++;
    
  }
for(var j = 0; j < FINAL_AMOUNT; j++){
    
    count++;
    
  }
endMono = new DateTime.now();

myH1.appendHtml("main isolate: <b>"+endMono.difference(startMono).toString() + "</b><br/>");
}

void bigForCycle(){
  
  port.receive((data, SendPort replyTo){
    
    var count;
    for(var i = 0; i < FINAL_AMOUNT; i++){
      
      count = i;
      
    }
    
      replyTo.send(count);
    
  });
  
}
