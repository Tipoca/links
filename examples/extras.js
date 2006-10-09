// mandelbrot benchmarking
function _mandelbrot(x, y) {
  var bailout = 16.;
  var max_iterations = 200;
  var cr = y - 0.5;
  var ci = x;
  var zi = 0.0;
  var zr = 0.0;

  for(var i = 1; i <= max_iterations; i++) {
    var temp = zr * zi;
    var zr2 = zr * zr;
    var zi2 = zi * zi;
    zr = zr2 - zi2 + cr;
    zi = temp + temp + ci;
    if (zi2 + zr2 > bailout) return i;
  }
  return 0;
}
var jsmandelbrot =_continuationize(_mandelbrot, 2);

function _getCanvasById(id) {
  var node =_getNodeById(id);
  return node.getContext('2d'); 
}
function _canvasSetFillStyle(context, colour) {
  context.fillStyle = colour;
}
function _canvasFillRect(context, x, y, width, height) {
  context.fillRect(x, y, width, height);
}
var getCanvasById = _continuationize(_getCanvasById, 1);
var canvasSetFillStyle = _continuationize(_canvasSetFillStyle, 2);
var canvasFillRect = _continuationize(_canvasFillRect, 5);


function _plot(context, x, y) {
  _canvasFillRect(context, x*2, y*2, 2, 2);
}

function _fullyNativeMandelbrot() { 
  var width = 80;
  var height = 80;

  var base = "fullynative";

  var id;
  var i = 0;
  while(true) {
    var node = _getNodeById(base+i)
    if(node == null) {
      id = base+i;
      break;
    }
  }

  var body = _getNodeById("body"); 
  var div = document.createElement("div");
  div.innerHTML =
   "<canvas id=\""+id+
	    "\" width=\""+(2*width)+
            "\" height=\""+(2*height)+"\"></canvas>";

  var canvas = div.firstChild;
  _domAppendChildRef(canvas, body);
  
  var context = _getCanvasById(id);
  _canvasSetFillStyle(context, "red");
  
  var startTime = _getCurrentTime();

  for (y = -39; y <= 39; y++) {
    for (x = -39; x <= 39; x++) {
      if (_mandelbrot(x/40.0, y/40.0) == 0)
	_plot(context, x+39,y+39);
    }
  }

  var endTime = _getCurrentTime();
  var totalTime = (endTime-startTime);

  div.innerHTML = totalTime+"ms";
  _domInsertBeforeRef(div.firstChild, canvas)

  //domInsertBefore(enxml(string_of_int(totalTime)++"ms"), getNodeById(id));
  //debug("Time to draw "++id++": "++string_of_int(totalTime)++"ms") 
}
var fullyNativeMandelbrot = _continuationize(_fullyNativeMandelbrot, 0);


function _getCurrentTime() {
  return (new Date()).getTime();
}
var getCurrentTime = _continuationize(_getCurrentTime, 0);
