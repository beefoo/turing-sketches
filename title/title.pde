/*
 * You Drawing You (http://youdrawingyou.com)
 * Author: Brian Foo (http://brianfoo.com)
 * This drawing algorithm is based on my friend Rahul (http://youdrawingyou.com/sketches/rahul)
 */
 
import processing.pdf.*;

String imgSrc = "title.jpg";
String outputFile = "output/title.png";
String outputPDF = "output/title.pdf";
boolean savePDF = false;

int spaceWidth = 1024;
int spaceHeight = 768;
int startX = round(spaceWidth/2);
int startY = round(spaceHeight/2);
int gridUnit = 25;
float angleUnit = 10;

int fr = 120;
String outputMovieFile = "output/frames/frames-#####.png";
int frameCaptureEvery = 6;
int frameIterator = 0;
boolean captureFrames = false;
FrameSaver fs;

PGraphics pg;
PImage space;
RahulGang theRahulGang;
color[] bins;
float[] pathDirections;

void setup() {
  
  // set the stage
  size(spaceWidth, spaceHeight);
  colorMode(HSB, 360, 100, 100, 100);
  background(0, 0, 100);
  frameRate(fr);
  pg = createGraphics(spaceWidth, spaceHeight);
  
  // load space from image source
  space = loadImage(imgSrc);
  pg.image(space, 0, 0);
  pg.loadPixels();
  
  // set the bins and create a Rahul Gang  
  bins = pg.pixels;
  pathDirections = new float[spaceWidth*spaceHeight];
  theRahulGang = new RahulGang(startX, startY);
  
  // output methods
  if (captureFrames) fs = new FrameSaver();  
  if (savePDF) beginRecord(PDF, outputPDF);
}

void draw(){
  noFill();
  if(captureFrames && !fs.running) {
    fs.start();
  }
  
  theRahulGang.loot();
}

void mousePressed() {  
  if (captureFrames) {
    fs.quit();
  } else {
    save(outputFile);
  }  
  if (savePDF) endRecord();
  exit();
}

class Rahul
{
  int capacity = 2000;
  
  float chanceToDuplicate = 0.5;
  float chanceToChangeDirection = 0.5;
  float chanceToAdoptIntersectedPath = 0.4;
  float chanceToAdoptNeighborPath = 0.1;
  
  int myX, myY, myStuffCount;
  float myDirection; // 1-360
  boolean iAmDead;
  Bin myBin;
  
  Rahul (int x, int y, int stuffCount, float direction) {
    myX = x;
    myY = y;
    myStuffCount = stuffCount;
    myDirection = normalizeAngle(direction);
    iAmDead = false;
  }
  
  Bin chooseABin() {
    int[] nextPosition = getNewPosition(myX, myY, myDirection, gridUnit);
    float chance = random(0,1);    
    float direction;
    Bin nextBin = new Bin(nextPosition[0], nextPosition[1]);
    
    // if next bin is not empty and in bounds
    if (!nextBin.isEmpty() && nextBin.isInBounds()) {

      if (nextBin.wasVisited() && chance < chanceToAdoptIntersectedPath) {
        myDirection = nextBin.visitorsDirection();        
        
      } else if (nextBin.neighborsAverageDirection() > 0 && chance < chanceToAdoptNeighborPath) {
        myDirection = nextBin.neighborsAverageDirection();
        
      } else if (chance < chanceToChangeDirection) {
        myDirection = nudgeAngle(myDirection);
      }
      
      nextPosition = getNewPosition(myX, myY, myDirection, gridUnit);
      nextBin = new Bin(nextPosition[0], nextPosition[1]);
      
    // if next bin is empty or out-of-bounds
    } else {
      nextBin = getClosestAvailableBin();
    }
  
    return nextBin;  
  }
  
  void drawPath(int x1, int y1, int x2, int y2, int iterator) {    
    strokeWeight(0.1);
    line(x1, y1, x2, y2);
  }
  
  void die(){
    iAmDead = true;
  }
  
  void dropEverything() {
    myStuffCount = 0;
  }
  
  Rahul duplicate(){
    // make a new Rahul with half my stuff and a different direction
    float newDirection = nudgeAngle(myDirection);
    Rahul newRahul = new Rahul(myX, myY, floor(myStuffCount/2), newDirection);
    
    // halve my own stuff
    myStuffCount = ceil(myStuffCount/2);
    
    return newRahul;
  }
  
  float getChanceToDuplicate(){
    return chanceToDuplicate;
  }
  
  Bin getClosestAvailableBin(){
    boolean binFound = false, first = true;
    Bin closestBin = new Bin(0, 0);
    
    for(int a=int(angleUnit); a<=180 && !binFound; a+=int(angleUnit)) {
      for(int b=-1; b<=1 && !binFound; b+=2) {
        
        float direction = normalizeAngle(myDirection+float(b * a));
        int[] position = getNewPosition(myX, myY, direction, gridUnit);
        Bin bin = new Bin(position[0], position[1]);
        
        // default to first in-bounds bin
        if (first && bin.isInBounds()) {
          closestBin = bin;
          first = false; 
        }
        
        if (!bin.isEmpty() && bin.isInBounds()) {
          closestBin = bin;
          binFound = true;
        }
        
      }      
    }
    
    return closestBin;
  }
  
  int[] getNewPosition(int x, int y, float angle, float distance){
    int[] coords = new int[2];
    float r = radians(angle);
    
    coords[0] = x + round(distance*cos(r));
    coords[1] = y + round(distance*sin(r));
    
    return coords;
  }
  
  int getStuffCount(){
    return myStuffCount;
  }
 
  boolean isAlive(){
    return (!iAmDead);
  } 
  
  boolean isOverCapacity(){
    return (myStuffCount >= capacity);
  }
  
  boolean loot(){
    boolean foundStuff = false;
    int dieAfter = 1000; // die after this many failed tries
    int i = 0;
    
    // move until i find stuff
    while(!foundStuff){
      foundStuff = move(i);
      i++;
      if (i>dieAfter) {
        die();
        break;
      }
    }
    
    if (foundStuff) {
      stealStuff();
    }
    
    return foundStuff;    
  }
  
  boolean move(int iterator){
    // see if I can find a bin that's not empty or the current one
    myBin = chooseABin();    
    boolean foundStuff = (!myBin.isEmpty() && myBin.isInBounds() && !myBin.positionEquals(myX, myY));
    int prevX = myX;
    int prevY = myY;
    
    // stuff found
    if (foundStuff) {
      myX = myBin.getX();
      myY = myBin.getY();   
      stroke(40, 20, 20, 5);  
    
    // no stuff in any bin around me
    } else {      
      moveRandomly();
      foundStuff = true;   
      stroke(40, 20, 20, 3);   
    }
    
    myBin.setPathDirection(myDirection);
    
    // draw path
    if (iterator<1) drawPath(prevX, prevY, myX, myY, iterator);
    
    return foundStuff;       
  }
  
  void moveRandomly(){
    boolean binFound = false;
    int x = myX, y = myY, i=0;
    int[] newPosition = new int[2];
    float angle = random(1, 360), distance = 100;
  
    while(!binFound) {      
      newPosition = getNewPosition(x, y, angle, distance); 
      Bin bin = new Bin(newPosition[0], newPosition[1]);
      if (!bin.isEmpty()) {        
        binFound = true;
      }
      angle = random(1, 360);  
      i++;
      if (i%360 == 0) {
        distance += distance;
      }
      if (i>3000) {
        println("Timed out");
        break; 
      }
    }  
    
    if (binFound) {
      myDirection = angle;
      myX = newPosition[0];
      myY = newPosition[1];
      myBin = new Bin(myX, myY);
    } else {
      die();
    }  
  }
  
  float normalizeAngle(float angle){
    // round to nearest angle unit
    angle = round(angle/angleUnit)*angleUnit;
    
    // ensure I am within 1-360 degrees
    if (angle > 360) angle = angle - 360;
    else if (angle < 1) angle = 360 + angle;
    
    return angle;
  }
  
  float nudgeAngle(float angle) {
    float variance = angleUnit;
    if (random(-1,1) < 0) variance *= -1;
    return normalizeAngle(angle * variance);
  }
  
  void stealStuff() {
    float stuffAmount = myBin.take();    
    myStuffCount += round(stuffAmount);
  }
}

class RahulGang
{
  int gangSizeLimit = 50;  
  
  ArrayList<Rahul> gang;

  RahulGang (int x, int y) {    
    gang = new ArrayList<Rahul>();
    gang.add(new Rahul(x, y, 0, random(1, 360)));
  }
  
  void giveJudgementTo(Rahul rahul) {
    float judgement = random(0, 1);
    
    if (judgement < rahul.getChanceToDuplicate() && gang.size() < gangSizeLimit) {
      Rahul newRahul = rahul.duplicate();
      gang.add(newRahul);
      
    } else {
      rahul.dropEverything();
    }
  }

  void loot() {
    for (int i = gang.size()-1; i >= 0; i--) {
      Rahul rahul = gang.get(i);
      if (!rahul.isAlive()) continue;
      
      rahul.loot();
      
      if (rahul.isOverCapacity()) {
        giveJudgementTo(rahul);
      }
    }    
  } 

}

class Bin
{
  float stuffBrightness = 25; // a white pixel will have 100 brightness and thus about 5 things to take; < 20 brightness is considered empty
  
  float myHue, mySaturation, myBrightness;
  int myX, myY;
  
  Bin (int x, int y) {
    myX = x;
    myY = y;    
    ensureInBounds();
    
    // retrieve bin's current color
    color c = bins[myX+myY*spaceWidth];
    myHue = hue(c);
    mySaturation = saturation(c);
    myBrightness = brightness(c);
    
  }
  
  void ensureInBounds(){
    if (myX < gridUnit) myX = gridUnit;
    if (myY < gridUnit) myY = gridUnit;
    if (myX > spaceWidth-gridUnit-1) myX = spaceWidth-gridUnit-1;
    if (myY > spaceHeight-gridUnit-1) myY = spaceHeight-gridUnit-1;
  }
  
  float getBrightness() {
    return myBrightness; 
  }
  
  int getX(){
    return myX;
  }
  
  int getY(){
    return myY;
  }
  
  boolean isEmpty(){    
    return (myBrightness < stuffBrightness);
  }
  
  boolean isInBounds(){
    return (myX>=gridUnit 
              && myY>=gridUnit 
              && myX<=spaceWidth-gridUnit-1
              && myY<=spaceHeight-gridUnit-1);
  }
  
  float neighborsAverageDirection(){
    int[] delta = {0, -1};
    int dx = 0, dy = 0, directionCount = 0;
    float directionsTotal = 0, averageDirection = 0;
    
    // go in a counter-clockwise spiral around me
    for(int i=0; i<8; i++) {
      
      // change directions
      if (dx==dy || (dx<0 && dx==(-1*dy)) || (dx>0 && dx==(1-dy))) {
        int temp = delta[0];
        delta[0] = -1*delta[1];
        delta[1] = temp;          
      }      
      
      // add delta
      dx += delta[0];
      dy += delta[1];
     
      // check if bin was visited     
      Bin bin = new Bin(myX+dx*gridUnit, myY+dy*gridUnit);
      if (bin.wasVisited()){
        directionsTotal += bin.visitorsDirection();
        directionCount++;
      }           
    }
    
    if (directionCount > 0) {
      averageDirection = directionsTotal/directionCount;
    }
    
    return averageDirection;
  }
  
  boolean positionEquals(int x, int y) {
    return (x==myX && y==myY);
  }
  
  void setPathDirection(float direction){
    if (!wasVisited()) {
      pathDirections[myX+myY*spaceWidth] = direction;
    }
  }
  
  float take(){
    float stuffAmount = stuffBrightness;
    
    myBrightness -= stuffAmount;
    
    // can't have stuff with a negative brightness
    if (myBrightness<0) {
      stuffAmount += myBrightness;
      myBrightness = 0;
    }
    if (stuffAmount<0) {
      stuffAmount = 0; 
    }
    
    // update bin    
    color c = color(myHue, mySaturation, myBrightness);
    bins[myX+myY*spaceWidth] = c;
    
    return stuffAmount;
  }
  
  float visitorsDirection(){
    return pathDirections[myX+myY*spaceWidth];
  }
  
  boolean wasVisited(){
    return (visitorsDirection() > 0);
  }
  
}

class FrameSaver extends Thread {
 
  boolean running;
   
  public FrameSaver () {
    running = false;
  }
   
  public void start() {
    println("recording frames!");
    running = true;
   
    try{
      super.start();
    }
    catch(java.lang.IllegalThreadStateException itse){
      println("cannot execute! ->"+itse);
    }
  }
   
  public void run(){
    while(running){
      frameIterator++;
      if (frameIterator >= frameCaptureEvery) {
        frameIterator = 0;
        saveFrame(outputMovieFile);
      }      
    }
  }
   
  public void quit() {
    println("stopped recording..");
    running = false; 
    interrupt();
  }
}
